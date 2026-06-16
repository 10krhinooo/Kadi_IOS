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

/// Glowing gold button style for the KADI declaration — stands out among other actions.
struct KadiDeclareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        KadiDeclareButtonBody(configuration: configuration)
    }
}

private struct KadiDeclareButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var glowing = false

    var body: some View {
        configuration.label
            .font(.system(.title3, design: .rounded).weight(.black))
            .foregroundStyle(KadiTheme.Colors.background)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(KadiTheme.Colors.accent.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
            .shadow(color: KadiTheme.Colors.accent.opacity(glowing ? 0.85 : 0.25),
                    radius: glowing ? 14 : 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    glowing = true
                }
            }
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
