import SwiftUI
import AuthenticationServices

struct AccountView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        ScrollView {
            if auth.isSignedIn {
                signedIn
            } else {
                signedOut
            }
        }
        .background(RxTheme.bg)
        .scrollIndicators(.hidden)
    }

    // MARK: Signed out

    private var signedOut: some View {
        VStack(spacing: 22) {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(RxTheme.accent.opacity(0.14))
                    Image(systemName: "person.badge.key")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(RxTheme.accent)
                }
                .frame(width: 84, height: 84)

                Text("Sign in to Rx Manager")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(RxTheme.ink)
                Text("Back up your medications and get text refill reminders across your devices.")
                    .font(.system(size: 14))
                    .foregroundStyle(RxTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .padding(.top, 48)

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    auth.prepareAppleRequest(request)
                } onCompletion: { result in
                    Task { await auth.completeAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Text("Email & password — coming next")
                    .font(.system(size: 13))
                    .foregroundStyle(RxTheme.muted)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 24)

            if auth.isWorking {
                ProgressView().padding(.top, 4)
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: 0xb42318))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            #if DEBUG
            Button("Preview account (dev)") { auth.mockSignIn() }
                .font(.system(size: 12))
                .foregroundStyle(RxTheme.muted)
                .padding(.top, 8)
            #endif

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Signed in

    private var signedIn: some View {
        VStack(spacing: 16) {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(RxTheme.accent)
                    Text(auth.initials)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 84, height: 84)

                VStack(spacing: 3) {
                    Text(auth.displayName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(RxTheme.ink)
                    if let email = auth.session?.user.email, !email.isEmpty,
                       email != auth.displayName {
                        Text(email)
                            .font(.system(size: 13))
                            .foregroundStyle(RxTheme.muted)
                    }
                }

                Text("Signed in with Apple")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(RxTheme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(RxTheme.accent.opacity(0.12), in: Capsule())
            }
            .padding(.top, 36)

            card {
                row("Sync", "Coming soon")
                divider
                row("Reminders", "Set up in Settings")
            }

            Button(role: .destructive) { auth.signOut() } label: {
                Text("Sign out")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RxTheme.card, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color(hex: 0xb42318))
            }
            .padding(.top, 4)

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }

    // MARK: Pieces

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RxTheme.card, in: RoundedRectangle(cornerRadius: RxTheme.cardRadius))
            .shadow(color: RxTheme.cardShadow, radius: 10, y: 5)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundStyle(RxTheme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(RxTheme.ink)
        }
    }

    private var divider: some View {
        Rectangle().fill(RxTheme.ink.opacity(0.06)).frame(height: 1)
    }
}
