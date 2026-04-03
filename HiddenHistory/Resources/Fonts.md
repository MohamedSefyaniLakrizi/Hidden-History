# Inter Font Files

This folder must contain the Inter font TTF files before building.

## Download

1. Go to https://rsms.me/inter/ and click **Download Inter**
2. Extract the zip and copy these files here:
   - `Inter-Regular.ttf`
   - `Inter-Medium.ttf`
   - `Inter-SemiBold.ttf`
   - `Inter-Bold.ttf`

The `project.yml` already registers all four files in `Info.plist` under `UIAppFonts`.
These files are gitignored via the `*.ttf` rule — each developer must download them locally.
