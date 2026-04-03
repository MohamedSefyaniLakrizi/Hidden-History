# Hidden History — Data Architecture

> **For agents**: This document covers the complete data model, all external data sources,
> the enrichment pipeline, and Supabase configuration. Consult this when working on anything
> involving the database, Edge Functions, or historical content ingestion.

---

## Overview

Historical site data is assembled from multiple free public sources, merged,
deduplicated, enriched with descriptions and images from Wikipedia, and stored
in a Supabase PostgreSQL database with the PostGIS extension for geospatial queries.

Audio narrations are generated on-demand via AWS Polly (free tier) and ElevenLabs
(premium tier) and cached permanently in Supabase Storage.

---

## Database: Supabase + PostGIS

### Enable PostGIS

```sql
-- Run once in Supabase SQL editor
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- for fuzzy name matching during dedup
```

### Core Schema

```sql
-- ============================================================
-- HISTORICAL SITES
-- ============================================================
CREATE TABLE historical_sites (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                TEXT NOT NULL,
  slug                TEXT UNIQUE NOT NULL,          -- url-safe identifier
  description         TEXT,                          -- full Wikipedia-sourced text
  short_bio           TEXT,                          -- 1–2 sentence preview
  geom                GEOGRAPHY(POINT, 4326) NOT NULL,
  lat                 DOUBLE PRECISION NOT NULL,
  lng                 DOUBLE PRECISION NOT NULL,
  address             TEXT,
  city                TEXT,
  country_code        CHAR(2),                       -- ISO 3166-1 alpha-2
  site_type           TEXT NOT NULL DEFAULT 'other', -- see site_types enum below
  era                 TEXT,                          -- see eras enum below
  built_year          INT,
  demolished          BOOL NOT NULL DEFAULT false,
  hero_image_url      TEXT,                          -- Wikipedia Commons image
  audio_url_free      TEXT,                          -- Polly .mp3 in Storage
  audio_url_premium   TEXT,                          -- ElevenLabs .mp3 in Storage
  audio_duration_sec  INT,
  audio_generated_at  TIMESTAMPTZ,
  wikipedia_id        TEXT,                          -- Wikipedia page title
  wikidata_id         TEXT,                          -- Q-number e.g. Q12345
  osm_id              TEXT,                          -- OSM node/way/relation id
  osm_type            TEXT,                          -- node, way, relation
  source              TEXT NOT NULL,                 -- wikidata, osm, historic_england, nrhp, manual
  verified            BOOL NOT NULL DEFAULT false,
  view_count          INT NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Spatial index (CRITICAL — without this, proximity queries are full table scans)
CREATE INDEX idx_sites_geom         ON historical_sites USING GIST (geom);
CREATE INDEX idx_sites_country      ON historical_sites (country_code);
CREATE INDEX idx_sites_city         ON historical_sites (city);
CREATE INDEX idx_sites_era          ON historical_sites (era);
CREATE INDEX idx_sites_site_type    ON historical_sites (site_type);
CREATE INDEX idx_sites_verified     ON historical_sites (verified);
CREATE INDEX idx_sites_name_trgm    ON historical_sites USING GIN (name gin_trgm_ops);

-- ============================================================
-- CATEGORIES (many-to-many)
-- ============================================================
CREATE TABLE site_categories (
  site_id  UUID NOT NULL REFERENCES historical_sites(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  PRIMARY KEY (site_id, category)
);

-- ============================================================
-- USER HISTORY (per-user interaction log)
-- ============================================================
CREATE TABLE user_history (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  site_id     UUID NOT NULL REFERENCES historical_sites(id) ON DELETE CASCADE,
  visited_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  listened    BOOL NOT NULL DEFAULT false,
  listen_pct  INT,                    -- 0–100, percent of audio heard
  saved       BOOL NOT NULL DEFAULT false,
  UNIQUE (user_id, site_id)
);

CREATE INDEX idx_user_history_user ON user_history (user_id);
CREATE INDEX idx_user_history_site ON user_history (site_id);

-- ============================================================
-- SITE IMAGES (multiple images per site, future use)
-- ============================================================
CREATE TABLE site_images (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id     UUID NOT NULL REFERENCES historical_sites(id) ON DELETE CASCADE,
  storage_url TEXT NOT NULL,
  caption     TEXT,
  credit      TEXT,
  is_hero     BOOL NOT NULL DEFAULT false,
  sort_order  INT NOT NULL DEFAULT 0
);
```

### Enum Values

**site_type** (stored as TEXT — no enum type, easier to extend):
`monument`, `building`, `church`, `castle`, `bridge`, `museum`, `park`, `battlefield`,
`cemetery`, `ruins`, `archaeological_site`, `industrial`, `residential`, `statue`,
`fountain`, `gate`, `tower`, `market`, `school`, `theatre`, `other`

**era** (stored as TEXT):
`prehistoric`, `ancient`, `roman`, `medieval`, `renaissance`, `early_modern`,
`industrial`, `victorian`, `edwardian`, `world_war_i`, `interwar`, `world_war_ii`,
`postwar`, `modern`, `contemporary`

---

## Key Database Queries

### Proximity Search (Primary Query)

```sql
-- Find all verified sites within :radius_meters of a point, ordered by distance
-- Uses PostGIS spatial index — very fast even with millions of rows

SELECT
  id,
  name,
  short_bio,
  lat,
  lng,
  site_type,
  era,
  hero_image_url,
  audio_duration_sec,
  ST_Distance(
    geom,
    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
  ) AS distance_meters
FROM historical_sites
WHERE
  verified = true
  AND ST_DWithin(
    geom,
    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
    :radius_meters    -- e.g. 2000 for 2km
  )
ORDER BY
  geom <-> ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
LIMIT 100;
```

### Viewport Query (Map pan/zoom)

```sql
-- Find sites within the visible map bounding box
SELECT id, name, lat, lng, site_type, hero_image_url
FROM historical_sites
WHERE
  verified = true
  AND ST_Intersects(
    geom,
    ST_MakeEnvelope(:min_lng, :min_lat, :max_lng, :max_lat, 4326)::geography::geometry
  )
LIMIT 200;
```

### Full-Text + Fuzzy Name Search

```sql
-- Using pg_trgm for fuzzy matching
SELECT id, name, city, short_bio, lat, lng
FROM historical_sites
WHERE
  verified = true
  AND name % :query          -- trigram similarity
ORDER BY similarity(name, :query) DESC
LIMIT 20;
```

---

## Data Sources

### 1. OpenStreetMap Overpass API

**URL**: `https://overpass-api.de/api/interpreter`
**Purpose**: Geographic coordinates of `historic=*` tagged places
**Coverage**: Global (~2M+ historic POIs)
**Cost**: Free (rate-limited; use reasonable query intervals)

**Query template** (for a bounding box):
```
[out:json][timeout:60];
(
  node["historic"]({{bbox}});
  way["historic"]({{bbox}});
  relation["historic"]({{bbox}});
);
out center tags;
```

**Relevant `historic=*` values to import**:
`monument`, `memorial`, `building`, `castle`, `church`, `ruins`, `archaeological_site`,
`battlefield`, `fort`, `gate`, `tower`, `bridge`, `milestone`, `wayside_cross`,
`manor`, `house`, `yes`

**Fields extracted**:
- `id` → `osm_id`
- `type` (node/way/relation) → `osm_type`
- `lat`/`lon` → coordinates
- `tags.name` → `name`
- `tags.historic` → `site_type`
- `tags.start_date` → `built_year` (parse year)
- `tags.wikipedia` → link to Wikipedia article
- `tags.wikidata` → `wikidata_id`
- `tags.addr:city` → `city`

---

### 2. Wikidata SPARQL

**URL**: `https://query.wikidata.org/sparql`
**Purpose**: Structured historical data with coordinates, dates, Wikipedia links
**Cost**: Free (60s query timeout; paginate large results)

**Sample SPARQL query** (historic buildings with coords):
```sparql
SELECT DISTINCT ?item ?itemLabel ?coords ?inceptionYear ?wikipediaUrl ?countryCode WHERE {
  ?item wdt:P31 ?type.
  VALUES ?type {
    wd:Q839954   # archaeological site
    wd:Q44377    # castle
    wd:Q16560    # palace
    wd:Q483110   # stadium (for historic ones)
    wd:Q12280    # bridge
  }
  ?item wdt:P625 ?coords.
  OPTIONAL { ?item wdt:P571 ?inception. BIND(YEAR(?inception) AS ?inceptionYear) }
  OPTIONAL {
    ?article schema:about ?item;
             schema:isPartOf <https://en.wikipedia.org/>.
    BIND(STR(?article) AS ?wikipediaUrl)
  }
  OPTIONAL { ?item wdt:P17 ?country. ?country wdt:P297 ?countryCode. }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
LIMIT 5000
OFFSET 0
```

**Fields extracted**:
- `?item` → `wikidata_id` (strip `wd:` prefix)
- `?itemLabel` → `name`
- `?coords` → parse `Point(lng lat)` format
- `?inceptionYear` → `built_year`
- `?wikipediaUrl` → used to fetch description
- `?countryCode` → `country_code`

---

### 3. Wikipedia REST API

**URL**: `https://en.wikipedia.org/api/rest_v1/page/summary/{title}`
**Purpose**: Rich description text and hero images
**Cost**: Free (rate limit: ~200 req/s; use backoff)

**Response fields used**:
- `extract` → `description` (first 500 chars → `short_bio`, full → `description`)
- `thumbnail.source` → `hero_image_url`
- `content_urls.desktop.page` → page URL (for attribution)

---

### 4. Historic England — National Heritage List (NHLE)

**URL**: `https://api.historicengland.org.uk/historicengland/service/open-data/`  
**Alternative**: GIS download from `opendata-historicengland.hub.arcgis.com`
**Purpose**: Authoritative UK listed buildings + scheduled monuments
**Coverage**: ~400,000 entries across England
**Cost**: Free (open data licence)

**Fields**:
- `ListEntry` → mapped to `historical_sites`
- Grade I, II*, II → stored as `verified = true`
- Includes precise coordinates, designation date, architectural descriptions

**Import strategy**: Batch download GIS CSV/shapefile → parse + upsert via Edge Function

---

### 5. US National Register of Historic Places (NRHP)

**URL**: `https://www.nps.gov/subjects/nationalregister/data-downloads.htm`
**Purpose**: US historic places (~100,000 individual listings)
**Cost**: Free (public domain)

**Format**: Spreadsheet download, updated periodically
**Fields**: Name, state, county, latitude, longitude, date_listed, resource_type

**Import strategy**: Download CSV → normalise coordinates → batch upsert

---

## Data Enrichment Pipeline

### Edge Functions Overview

All Edge Functions live in `supabase/functions/` and are written in TypeScript/Deno.

```
supabase/functions/
├── sync-osm/            Nightly OSM Overpass import
│   ├── index.ts
│   └── tests/
├── sync-wikidata/       Nightly Wikidata SPARQL import
│   ├── index.ts
│   └── tests/
├── enrich-site/         Called after new site insert — fetches Wikipedia content
│   ├── index.ts
│   └── tests/
└── generate-audio/      Generates Polly + ElevenLabs audio for a site
    ├── index.ts
    └── tests/
```

### Edge Function: `generate-audio`

Called when `audio_url_free` is NULL on a verified site.

```typescript
// supabase/functions/generate-audio/index.ts

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  const { site_id } = await req.json()

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Fetch site
  const { data: site } = await supabase
    .from('historical_sites')
    .select('name, description, short_bio')
    .eq('id', site_id)
    .single()

  const narrationText = buildNarrationScript(site)

  // Generate free (Polly)
  const pollyAudio = await generatePollyAudio(narrationText)
  const freeUrl = await uploadToStorage(supabase, `narrations/${site_id}_free.mp3`, pollyAudio)

  // Generate premium (ElevenLabs)
  const elevenAudio = await generateElevenLabsAudio(narrationText)
  const premiumUrl = await uploadToStorage(supabase, `narrations/${site_id}_premium.mp3`, elevenAudio)

  // Persist URLs + duration
  await supabase.from('historical_sites').update({
    audio_url_free: freeUrl,
    audio_url_premium: premiumUrl,
    audio_duration_sec: estimateDuration(narrationText),
    audio_generated_at: new Date().toISOString()
  }).eq('id', site_id)

  return new Response(JSON.stringify({ success: true }))
})

function buildNarrationScript(site: { name: string; description: string | null; short_bio: string | null }): string {
  // Builds a ~400-word natural narration from structured data
  // Polly: ~1200 chars ≈ 60 seconds at normal pace
  // ElevenLabs: same script, different voice
  return `${site.name}. ${site.description ?? site.short_bio ?? 'No description available.'}`
    .substring(0, 1500)  // cap to control cost
}
```

**Narration Script Guidelines**:
- ~300–500 words per site (≈2–3 min audio)
- Opens with site name + era
- Covers: what it is, when it was built, key historical events, current status
- Closes with a curiosity hook ("What you might not know is...")
- No markdown, no footnotes — pure spoken-word prose

### Edge Function: `enrich-site`

Triggered by Supabase DB webhook `after INSERT on historical_sites WHERE description IS NULL`.

1. Look up `wikipedia_id` or search Wikipedia by `name + city`
2. Fetch `/api/rest_v1/page/summary/{title}`
3. Store `description`, `short_bio`, `hero_image_url`
4. Trigger `generate-audio` function

### Nightly Sync Cron

Supabase pg_cron (or external cron hitting an Edge Function):

```sql
-- Run at 02:00 UTC daily
SELECT cron.schedule(
  'sync-osm-london',
  '0 2 * * *',
  $$SELECT net.http_post('https://<project>.supabase.co/functions/v1/sync-osm', '{"city":"london"}')$$
);
```

---

## Supabase Storage Structure

```
Bucket: hidden-history-assets  (public, CDN-backed)
├── narrations/
│   ├── {site_id}_free.mp3        AWS Polly audio
│   └── {site_id}_premium.mp3     ElevenLabs audio
├── images/
│   ├── sites/
│   │   └── {site_id}_hero.jpg    Cached Wikipedia image
│   └── icons/
│       └── app-icon.png
└── exports/
    └── {user_id}/
        └── history_{date}.pdf    Premium PDF exports
```

**Cache policy**: `Cache-Control: public, max-age=31536000` (1 year) on all audio files.
Audio narrations never change after generation — safe to cache indefinitely.

---

## Data Quality & Verification

### Verification Levels

| `verified` | Meaning |
|------------|---------|
| `false` | Imported from OSM/Wikidata, not human-reviewed |
| `true` | Either from authoritative source (NHLE, NRHP) or manually reviewed |

MVP: show all sites to users. Mark clearly in UI if `verified = false`.
Phase 2: manual review queue in Supabase Studio.

### Deduplication

During import, match on:
1. Exact `wikidata_id` match → same site, update fields
2. `osm_id` match → same site, update fields
3. Name trigram similarity > 0.8 AND distance < 50m → likely same site, flag for review

---

## Row Level Security (RLS)

```sql
-- historical_sites: public read, no direct write from clients
ALTER TABLE historical_sites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read access"
  ON historical_sites FOR SELECT
  USING (verified = true);

-- user_history: users can only read/write their own rows
ALTER TABLE user_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own history"
  ON user_history FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users write own history"
  ON user_history FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own history"
  ON user_history FOR UPDATE
  USING (auth.uid() = user_id);
```

---

## iOS Data Flow

```
User moves map / grants location
         ↓
MapViewModel.loadSites(near: coordinate, radius: 2000)
         ↓
FetchNearbySitesUseCase.execute(near:radiusMeters:)
         ↓
SupabaseSiteRepository.fetchNearbySites(...)
         ↓ (URLSession + Supabase Swift SDK)
POST /rest/v1/rpc/nearby_sites  (or direct table query with PostGIS filter)
         ↓
[HistoricalSite] decoded from JSON DTOs
         ↓
MapViewModel.sites updated → View re-renders pins
```

### Audio Flow

```
User taps "Listen" on SiteDetailView
         ↓
PlayAudioUseCase.execute(site:, tier: .free | .premium)
         ↓
Checks: is audio_url_free / audio_url_premium populated?
  YES → SupabaseAudioRepository.getStreamURL(siteId:tier:)
         ↓ Returns CDN public URL
        AVPlayer(url: cdnUrl) → stream starts
  NO  → POST /functions/v1/generate-audio { site_id }
         ↓ Edge Function generates + uploads + returns URL
        Poll / webhook → AVPlayer starts once ready
```

Offline (premium): `AVAssetDownloadURLSession` downloads to device Documents folder.
`AudioCache.swift` tracks downloaded files, maps site_id → local URL.
