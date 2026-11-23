import Foundation

enum Config {
    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.10.1"
    // Public values (safe to keep in the app). Secrets live only on the server.
    static let supabaseURL = URL(string: "https://seimbpskeemozcibybsy.supabase.co")!
    static let supabasePublishableKey = "sb_publishable_h5MfmS1nk907f6_1gwjm-Q_7JsUwDpI"
}
