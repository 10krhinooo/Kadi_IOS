//
//  AvatarPickerView.swift
//  kadi
//

import SwiftUI

/// Canonical mapping from `Player.avatarIndex` (wire-compatible Int) to a displayed SF
/// Symbol + tint, shared by `AvatarPickerView`, `OpponentSlotView`, and lobby rows.
/// Index 0 matches the avatar Phase 4a hardcoded into `OpponentSlotView`, so existing
/// screens render identically.
enum AvatarCatalog {
    struct Entry {
        let symbol: String
        let tint: Color
    }

    static let entries: [Entry] = [
        Entry(symbol: "person.crop.circle.fill", tint: KadiTheme.Colors.textSecondary),
        Entry(symbol: "person.crop.circle.fill", tint: KadiTheme.Colors.suitRed),
        Entry(symbol: "person.crop.circle.fill", tint: KadiTheme.Colors.success),
        Entry(symbol: "person.crop.circle.fill", tint: KadiTheme.Colors.warning),
        Entry(symbol: "star.circle.fill", tint: KadiTheme.Colors.accent),
        Entry(symbol: "moon.stars.circle.fill", tint: KadiTheme.Colors.suitRed),
        Entry(symbol: "bolt.circle.fill", tint: KadiTheme.Colors.success),
        Entry(symbol: "flame.circle.fill", tint: KadiTheme.Colors.warning),
    ]

    static func entry(for avatarIndex: Int) -> Entry {
        guard entries.indices.contains(avatarIndex) else { return entries[0] }
        return entries[avatarIndex]
    }
}

/// Small circular avatar glyph for `avatarIndex`, used in lobby rows, opponent slots, and
/// the picker grid itself.
struct AvatarView: View {
    let avatarIndex: Int
    var size: CGFloat = 28
    var isHighlighted: Bool = false

    var body: some View {
        let entry = AvatarCatalog.entry(for: avatarIndex)
        Image(systemName: entry.symbol)
            .font(.system(size: size))
            .foregroundStyle(isHighlighted ? KadiTheme.Colors.accent : entry.tint)
    }
}

/// Grid of selectable avatar choices for `LANSetupView`. Highlights the currently
/// selected `avatarIndex` with an accent ring.
struct AvatarPickerView: View {
    @Binding var selectedAvatarIndex: Int

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: KadiTheme.Layout.spacingM) {
            ForEach(AvatarCatalog.entries.indices, id: \.self) { index in
                Button {
                    selectedAvatarIndex = index
                } label: {
                    AvatarView(avatarIndex: index, size: 32)
                        .padding(KadiTheme.Layout.spacingM)
                        .background(
                            Circle().fill(KadiTheme.Colors.surfaceElevated)
                        )
                        .overlay(
                            Circle().stroke(
                                selectedAvatarIndex == index ? KadiTheme.Colors.accent : .clear,
                                lineWidth: 2
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    AvatarPickerView(selectedAvatarIndex: .constant(0))
        .padding()
        .background(KadiTheme.Colors.tableFelt)
}
