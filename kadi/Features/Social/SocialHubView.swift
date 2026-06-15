//
//  SocialHubView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// "Profile" hub: links to `ProfileView`/`SettingsView` (Phase 4d-1),
/// `FriendsView`/`LeaderboardView` (Phase 4d-2), and
/// `ConversationsListView`/`GameInvitesView` (Phase 4d-3).
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

                NavigationLink {
                    ConversationsListView(authUser: authUser)
                } label: {
                    HStack {
                        Text("Messages")
                        if viewModel.unreadMessageCount > 0 {
                            PillBadge(text: "\(viewModel.unreadMessageCount)", tint: KadiTheme.Colors.warning)
                        }
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                NavigationLink {
                    GameInvitesView(authUser: authUser)
                } label: {
                    HStack {
                        Text("Game Invites")
                        if viewModel.pendingInviteCount > 0 {
                            PillBadge(text: "\(viewModel.pendingInviteCount)", tint: KadiTheme.Colors.warning)
                        }
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

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
