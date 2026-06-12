//
//  LobbyPlayerRowView.swift
//  kadi
//

import SwiftUI

/// A single row in a LAN lobby roster: avatar, name, and "You"/"Host" badges.
struct LobbyPlayerRowView: View {
    let name: String
    let avatarIndex: Int
    var isHost: Bool = false
    var isYou: Bool = false

    var body: some View {
        HStack(spacing: KadiTheme.Layout.spacingM) {
            AvatarView(avatarIndex: avatarIndex, size: 28)

            Text(name)
                .font(KadiTheme.Typography.body)
                .foregroundStyle(KadiTheme.Colors.textPrimary)

            if isYou {
                PillBadge(text: "You")
            }
            if isHost {
                PillBadge(text: "Host", tint: KadiTheme.Colors.accentMuted)
            }

            Spacer()
        }
        .padding(.vertical, KadiTheme.Layout.spacingS)
    }
}

#Preview {
    VStack {
        LobbyPlayerRowView(name: "Alice", avatarIndex: 0, isHost: true, isYou: true)
        LobbyPlayerRowView(name: "Bob", avatarIndex: 2)
    }
    .padding()
    .background(KadiTheme.Colors.background)
}
