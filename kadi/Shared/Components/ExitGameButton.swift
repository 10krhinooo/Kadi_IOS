//
//  ExitGameButton.swift
//  kadi
//

import SwiftUI

/// Toolbar button + confirmation alert for leaving an in-progress game. Used by
/// `SoloGameView`/`LANGameView`/`OnlineGameView`, whose back button is hidden while
/// `phase != .finished` — this is the only way to leave a game early.
struct ExitGameButton: ViewModifier {
    @State private var isConfirming = false
    let onExit: () -> Void

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isConfirming = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(KadiTheme.Colors.textSecondary)
                    }
                    .accessibilityLabel("Exit Game")
                }
            }
            .alert("Exit Game?", isPresented: $isConfirming) {
                Button("Exit", role: .destructive, action: onExit)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to leave this game? Your progress will be lost.")
            }
    }
}

extension View {
    /// Adds a leading toolbar "exit" button that confirms before calling `onExit`
    /// (typically `dismiss()`).
    func exitGameButton(onExit: @escaping () -> Void) -> some View {
        modifier(ExitGameButton(onExit: onExit))
    }
}
