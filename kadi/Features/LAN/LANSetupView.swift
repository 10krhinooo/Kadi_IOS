//
//  LANSetupView.swift
//  kadi
//

import SwiftUI

/// Entry screen for LAN multiplayer: prompts for a display name and avatar (persisted via
/// `PlayerIdentityStore`), then offers "Host Game" / "Join Game" navigation.
struct LANSetupView: View {
    @State private var identity = PlayerIdentityStore()
    @State private var name: String = ""
    @State private var avatarIndex: Int = 0

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingL) {
                Text("LAN Multiplayer")
                    .font(KadiTheme.Typography.title)
                    .foregroundStyle(KadiTheme.Colors.textPrimary)
                    .padding(.top, KadiTheme.Layout.spacingL)

                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                    Text("Your Name")
                        .font(KadiTheme.Typography.headline)
                        .foregroundStyle(KadiTheme.Colors.textPrimary)

                    TextField("Enter a display name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) { _, newValue in
                            identity.name = newValue
                        }
                }

                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                    Text("Avatar")
                        .font(KadiTheme.Typography.headline)
                        .foregroundStyle(KadiTheme.Colors.textPrimary)

                    AvatarPickerView(selectedAvatarIndex: $avatarIndex)
                        .onChange(of: avatarIndex) { _, newValue in
                            identity.avatarIndex = newValue
                        }
                }

                Spacer()

                VStack(spacing: KadiTheme.Layout.spacingM) {
                    NavigationLink {
                        LANHostLobbyView(identity: identity)
                    } label: {
                        Text("Host Game")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmedName.isEmpty)

                    NavigationLink {
                        LANJoinBrowserView(identity: identity)
                    } label: {
                        Text("Join Game")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(trimmedName.isEmpty)
                }
            }
            .padding(KadiTheme.Layout.spacingL)
        }
        .navigationTitle("LAN Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = identity.name
            avatarIndex = identity.avatarIndex
        }
    }
}

#Preview {
    NavigationStack {
        LANSetupView()
    }
}
