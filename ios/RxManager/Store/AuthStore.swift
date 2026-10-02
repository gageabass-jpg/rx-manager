import Foundation
import Observation
import AuthenticationServices
import CryptoKit

@Observable
final class AuthStore {
    var session: AuthSession?
    var errorMessage: String?
    var isWorking = false

    private var currentNonce: String?

    var isSignedIn: Bool { session != nil }
    var displayName: String {
        if let n = session?.user.name, !n.isEmpty { return n }
        return session?.user.email ?? "Your account"
    }
    var initials: String {
        let source = session?.user.name?.isEmpty == false ? session!.user.name! : (session?.user.email ?? "?")
        let parts = source.split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." })
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    init() { session = Keychain.loadSession() }

    // MARK: Sign in with Apple

    /// Configure the Apple request with scopes and a hashed nonce.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    @MainActor
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        switch result {
        case .failure(let error):
            if let authErr = error as? ASAuthorizationError, authErr.code == .canceled { return }
            errorMessage = "Apple sign-in didn’t finish. Please try again."

        case .success(let authorization):
            guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Couldn’t read your Apple credentials."
                return
            }
            let name = cred.fullName.flatMap(Self.formattedName)

            isWorking = true
            defer { isWorking = false }
            do {
                var newSession = try await SupabaseAuth.signInWithApple(idToken: idToken, nonce: nonce)
                // Apple only sends the name on the first authorization — keep it locally.
                if let name, (newSession.user.name ?? "").isEmpty {
                    newSession.user.name = name
                }
                session = newSession
                Keychain.saveSession(newSession)
            } catch let err as SupabaseAuth.AuthError {
                errorMessage = err.message
            } catch {
                errorMessage = "Couldn’t complete sign-in. Check your connection and try again."
            }
        }
    }

    /// A usable access token, refreshing first if it's expired or about to be.
    @MainActor
    func validAccessToken() async -> String? {
        guard let s = session else { return nil }
        if s.expiresAt.timeIntervalSinceNow > 60 { return s.accessToken }
        do {
            var refreshed = try await SupabaseAuth.refresh(refreshToken: s.refreshToken)
            if (refreshed.user.name ?? "").isEmpty { refreshed.user.name = s.user.name }
            session = refreshed
            Keychain.saveSession(refreshed)
            return refreshed.accessToken
        } catch {
            return s.accessToken   // let the caller surface a 401 if it's truly dead
        }
    }

    func signOut() {
        session = nil
        currentNonce = nil
        Keychain.deleteSession()
    }

    #if DEBUG
    /// Dev-only: preview the signed-in UI without a real Apple/Supabase round trip.
    func mockSignIn() {
        session = AuthSession(
            accessToken: "mock", refreshToken: "mock",
            expiresAt: Date().addingTimeInterval(3600),
            user: AuthUser(id: "mock-user", email: "you@example.com", name: "Gage Bass")
        )
    }
    #endif

    // MARK: Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if Int(random) < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func formattedName(_ components: PersonNameComponents) -> String? {
        let f = PersonNameComponentsFormatter()
        let s = f.string(from: components).trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }
}
