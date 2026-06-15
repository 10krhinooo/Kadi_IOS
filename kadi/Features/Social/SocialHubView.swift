//
//  SocialHubView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// "Profile" hub: links to `ProfileView`/`SettingsView` (Phase 4d-1) and
/// `FriendsView`/`LeaderboardView` (Phase 4d-2). Messages and Game Invites are
/// placeholders for Phase 4d-3.
struct SocialHubView: View {
    let authUser: AuthUser

    @StateObject private var viewModel = SocialHubViewModel()

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingM) {
                Spacer()

                NavigationLink {
                    ProfileView(authUser: authUser)
                } label: {
                    Text("Profile")
                }
                .buttonStyle(SecondaryButtonStyle())

                NavigationLink {
                    SettingsView(authUser: authUser)
                } label: {
                    Text("Settings")
                }
                .buttonStyle(SecondaryButtonStyle())

                NavigationLink {
                    FriendsView(authUser: authUser)
                } label: {
                    HStack {
                        Text("Friends")
                        if viewModel.pendingRequestCount > 0 {
                            PillBadge(text: "\(viewModel.pendingRequestCount)", tint: KadiTheme.Colors.warning)
                        }
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Messages") {}
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(true)
                    .opacity(0.4)

                Button("Game Invites") {}
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(true)
                    .opacity(0.4)

                NavigationLink {
                    LeaderboardView(authUser: authUser)
                } label: {
                    Text("Leaderboard")
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()
            }
            .padding(.horizontal, KadiTheme.Layout.spacingL)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.start(authUser: authUser)
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}
