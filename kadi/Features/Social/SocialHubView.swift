//
//  SocialHubView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// "Profile" hub: links to `ProfileView`/`SettingsView` (Phase 4d-1). Friends, Messages,
/// Game Invites, and Leaderboard are placeholders for Phase 4d-2.
struct SocialHubView: View {
    let authUser: AuthUser

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

                Button("Friends") {}
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(true)
                    .opacity(0.4)

                Button("Messages") {}
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(true)
                    .opacity(0.4)

                Button("Game Invites") {}
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(true)
                    .opacity(0.4)

                Button("Leaderboard") {}
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(true)
                    .opacity(0.4)

                Spacer()
            }
            .padding(.horizontal, KadiTheme.Layout.spacingL)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}
