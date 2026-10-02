import Foundation

struct AuthUser: Codable, Equatable {
    var id: String
    var email: String?
    var name: String?
}

struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var user: AuthUser
}

/// Minimal client for Supabase GoTrue auth over REST (no SDK dependency).
enum SupabaseAuth {
    struct AuthError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Exchange an Apple identity token for a Supabase session.
    static func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        try await token(grant: "id_token",
                         body: ["provider": "apple", "id_token": idToken, "nonce": nonce])
    }

    // MARK: Core request

    private static func token(grant: String, body: [String: Any]) async throws -> AuthSession {
        let url = AppConfig.supabaseURL
            .appendingPathComponent("auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: grant)])

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AuthError(message: "No response from server.")
        }
        guard http.statusCode == 200 else {
            throw AuthError(message: errorMessage(from: data) ?? "Server returned \(http.statusCode).")
        }
        return try session(from: data)
    }

    // MARK: Parsing

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_at: Double?
        let expires_in: Double?
        let user: UserResponse
    }

    private struct UserResponse: Decodable {
        let id: String
        let email: String?
        let user_metadata: Meta?
        struct Meta: Decodable {
            let full_name: String?
            let name: String?
        }
    }

    private static func session(from data: Data) throws -> AuthSession {
        let r = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expires: Date
        if let at = r.expires_at {
            expires = Date(timeIntervalSince1970: at)
        } else {
            expires = Date().addingTimeInterval(r.expires_in ?? 3600)
        }
        let name = r.user.user_metadata?.full_name ?? r.user.user_metadata?.name
        return AuthSession(
            accessToken: r.access_token,
            refreshToken: r.refresh_token,
            expiresAt: expires,
            user: AuthUser(id: r.user.id, email: r.user.email, name: name)
        )
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (obj["error_description"] as? String)
            ?? (obj["msg"] as? String)
            ?? (obj["error"] as? String)
    }
}
