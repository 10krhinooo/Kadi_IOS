//
//  KadiBanner.swift
//  kadi

import SwiftUI

/// Persistent banner shown to all players while a Kadi declaration is active.
struct KadiBanner: View {
    let playerName: String
    let isLocalPlayer: Bool

    @State private var appear = false
    @State private var pulse = false

    var body: some View {
        HStack(spacing: KadiTheme.Layout.spacingS) {
            Text(isLocalPlayer ? "You declared KADI!" : "\(playerName) declared KADI!")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(KadiTheme.Colors.background)
        }
        .padding(.horizontal, KadiTheme.Layout.spacingM)
        .padding(.vertical, 8)
        .background(
            KadiTheme.Colors.accent
                .shadow(.inner(radius: 2))
        )
        .clipShape(Capsule())
        .shadow(color: KadiTheme.Colors.accent.opacity(pulse ? 0.8 : 0.3), radius: pulse ? 10 : 4)
        .scaleEffect(appear ? 1 : 0.8)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                appear = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}
