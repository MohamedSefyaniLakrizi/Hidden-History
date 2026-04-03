import Foundation

/// Reads compile-time configuration keys injected via Config.xcconfig → Info.plist.
/// Add entries to Config.xcconfig (see Config.xcconfig.example) and reference them
/// in the Info.plist Custom iOS Target Properties section to expose them here.
enum Config {
    static var supabaseURL: String { value(for: "SUPABASE_URL") }
    static var supabaseAnonKey: String { value(for: "SUPABASE_ANON_KEY") }
    static var revenueCatAPIKey: String { value(for: "REVENUECAT_API_KEY") }
    static var postHogAPIKey: String { value(for: "POSTHOG_API_KEY") }

    private static func value(for key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty else {
            fatalError("Missing required config key '\(key)'. Check Config.xcconfig.")
        }
        return value
    }
}
