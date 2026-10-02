import Foundation
import Observation

/// Coordinates MedStore <-> Supabase for the signed-in user.
///
/// Strategy: one `user_meds` row per account. On an account change we adopt the
/// account's remote data (or migrate local-only data into a brand-new account).
/// For the same account we use last-write-wins on `updatedAt`.
@Observable
final class SyncService {
    enum Status: Equatable {
        case signedOut
        case syncing
        case synced(Date)
        case error(String)
    }

    var status: Status = .signedOut

    @ObservationIgnored private let meds: MedStore
    @ObservationIgnored private let auth: AuthStore
    @ObservationIgnored private var pushTask: Task<Void, Never>?

    private let lastUserKey = "rx.lastSyncedUserId"

    init(meds: MedStore, auth: AuthStore) {
        self.meds = meds
        self.auth = auth
        self.meds.onChange = { [weak self] in self?.schedulePush() }
    }

    // MARK: Triggers

    /// Debounced push after a local edit (also pulls to stay merged).
    func schedulePush() {
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
            await self?.syncNow()
        }
    }

    @MainActor
    func handleSignOut() {
        pushTask?.cancel()
        status = .signedOut
    }

    // MARK: Core

    @MainActor
    func syncNow() async {
        guard auth.isSignedIn, let uid = auth.session?.user.id else {
            status = .signedOut
            return
        }
        #if DEBUG
        if uid == "mock-user" { status = .synced(Date()); return }   // dev preview, no network
        #endif

        status = .syncing
        guard let token = await auth.validAccessToken() else {
            status = .error("You’re signed out.")
            return
        }

        let lastUser = UserDefaults.standard.string(forKey: lastUserKey)
        do {
            let remote = try await SupabaseDB.fetch(userId: uid, accessToken: token)

            if lastUser != uid {
                // First sign-in with this account, or switching accounts.
                if let remote {
                    meds.adopt(meds: remote.meds, settings: remote.settings, updatedAt: remote.updatedAt)
                } else if lastUser == nil {
                    // Migrate local-only data into the new account.
                    try await push(uid: uid, token: token)
                } else {
                    // Switched to an account with no data — start clean (don't leak the other account's data).
                    meds.adopt(meds: [], settings: AppSettings(), updatedAt: Date())
                    try await push(uid: uid, token: token)
                }
                UserDefaults.standard.set(uid, forKey: lastUserKey)
            } else if let remote {
                // Same account — last-write-wins.
                let delta = meds.updatedAt.timeIntervalSince(remote.updatedAt)
                if delta < -1 {
                    meds.adopt(meds: remote.meds, settings: remote.settings, updatedAt: remote.updatedAt)
                } else if delta > 1 {
                    try await push(uid: uid, token: token)
                }
            } else {
                try await push(uid: uid, token: token)
            }

            status = .synced(Date())
        } catch is SupabaseDB.AuthExpired {
            status = .error("Session expired — sign in again.")
        } catch {
            status = .error("Couldn’t sync. Check your connection.")
        }
    }

    @MainActor
    private func push(uid: String, token: String) async throws {
        try await SupabaseDB.upsert(userId: uid, meds: meds.meds, settings: meds.settings,
                                    updatedAt: meds.updatedAt, accessToken: token)
    }
}
