//
//  PillBadge.swift
//  kadi
//

import SwiftUI

/// A small rounded-capsule label, used for card counts, turn indicators, and status
/// callouts ("CPU thinking…", "Draw +N", "Kadi!").
struct PillBadge: View {
    let text: String
    var tint: Color = KadiTheme.Colors.accent
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(KadiTheme.Typography.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(KadiTheme.Colors.background)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tint)
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 8) {
        PillBadge(text: "Your Turn")
        PillBadge(text: "CPU thinking…", tint: KadiTheme.Colors.surfaceElevated)
        PillBadge(text: "Draw +4", tint: KadiTheme.Colors.warning)
        PillBadge(text: "5 cards", systemImage: "rectangle.stack.fill")
    }
    .padding()
    .background(KadiTheme.Colors.background)
}
