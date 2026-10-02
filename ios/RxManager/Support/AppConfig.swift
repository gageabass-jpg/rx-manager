import Foundation

/// Backend configuration. The Supabase anon key is a public client key —
/// data access is protected by row-level security on the server.
enum AppConfig {
    static let supabaseURL = URL(string: "https://dmznzmtbtlxlssffjqvi.supabase.co")!

    static let supabaseAnonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRtem56bXRidGx4bHNzZmZqcXZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxMTQ2NTMsImV4cCI6MjEwMzY5MDY1M30.a6Gb7Jg2bxRPOmSNfmjgUMW4UVo-YNYkPiaQTBd1PuM"
}
