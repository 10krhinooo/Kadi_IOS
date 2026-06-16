//
//  GameHelpButton.swift
//  kadi

import SwiftUI

/// Toolbar `?` button that presents `RulesView` as a sheet. Used by all three game screens.
struct GameHelpButton: ViewModifier {
    @State private var isShowingRules = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingRules = true
                    } label: {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(KadiTheme.Colors.textSecondary)
                    }
                    .accessibilityLabel("How to Play")
                }
            }
            .sheet(isPresented: $isShowingRules) {
                NavigationStack {
                    RulesView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { isShowingRules = false }
                            }
                        }
                }
            }
    }
}

extension View {
    func gameHelpButton() -> some View {
        modifier(GameHelpButton())
    }
}
