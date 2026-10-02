import Foundation

/// PostgREST client for the per-user `user_meds` row (RLS-scoped to auth.uid()).
enum SupabaseDB {
    struct RemoteState {
        var meds: [Medication]
        var settings: AppSettings
        var updatedAt: Date
    }

    struct AuthExpired: Error {}
    struct DBError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static var restURL: URL { AppConfig.supabaseURL.appendingPathComponent("rest/v1/user_meds") }

    // MARK: Fetch

    static func fetch(userId: String, accessToken: String) async throws -> RemoteState? {
        var comps = URLComponents(url: restURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "meds,settings,updated_at")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw DBError(message: "No response.") }
        if http.statusCode == 401 { throw AuthExpired() }
        guard http.statusCode == 200 else { throw DBError(message: "Fetch failed (\(http.statusCode)).") }

        let rows = try JSONDecoder().decode([Row].self, from: data)
        guard let row = rows.first else { return nil }
        return RemoteState(meds: row.meds, settings: row.settings,
                           updatedAt: parseTimestamp(row.updated_at))
    }

    // MARK: Upsert

    static func upsert(userId: String, meds: [Medication], settings: AppSettings,
                       updatedAt: Date, accessToken: String) async throws {
        var req = URLRequest(url: restURL)
        req.httpMethod = "POST"
        req.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")

        let body = UpsertRow(user_id: userId, meds: meds, settings: settings,
                             updated_at: iso8601(updatedAt))
        req.httpBody = try JSONEncoder().encode(body)

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw DBError(message: "No response.") }
        if http.statusCode == 401 { throw AuthExpired() }
        guard (200...299).contains(http.statusCode) else {
            throw DBError(message: "Save failed (\(http.statusCode)).")
        }
    }

    // MARK: Wire models

    private struct Row: Decodable {
        let meds: [Medication]
        let settings: AppSettings
        let updated_at: String
    }

    private struct UpsertRow: Encodable {
        let user_id: String
        let meds: [Medication]
        let settings: AppSettings
        let updated_at: String
    }

    // MARK: Timestamps

    private static func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    /// Parse a Postgres timestamptz, tolerating micro/nanosecond fractional parts.
    static func parseTimestamp(_ s: String) -> Date {
        let clamped = s.replacingOccurrences(of: #"\.(\d{3})\d+"#, with: ".$1",
                                             options: .regularExpression)
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: clamped) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: clamped) ?? .distantPast
    }
}
