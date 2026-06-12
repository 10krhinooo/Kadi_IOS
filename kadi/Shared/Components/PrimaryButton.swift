//
//  PrimaryButton.swift
//  kadi
//

import SwiftUI

/// Gold-filled call-to-action button style.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KadiTheme.Typography.buttonLabel)
            .foregroundStyle(KadiTheme.Colors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(KadiTheme.Colors.accent.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
    }
}

/// Subtle elevated-surface button style for secondary actions.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KadiTheme.Typography.buttonLabel)
            .foregroundStyle(KadiTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(KadiTheme.Colors.surfaceElevated.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius)
                    .stroke(Color.white.opacity(0.1))
            )
    }
}
