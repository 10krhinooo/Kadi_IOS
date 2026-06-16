//
//  RulesView.swift
//  kadi

import SwiftUI

struct RulesView: View {
    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingL) {

                    RulesSection(title: "Objective") {
                        RuleRow(text: "Be the first player to empty your hand.")
                        RuleRow(text: "To win, your last card must be one that can end the game (any card ranked 4–10 or a King).")
                        RuleRow(text: "You must declare \"KADI\" before or on your winning turn — tap the glowing KADI button when you're ready.")
                    }

                    RulesSection(title: "On Your Turn") {
                        RuleRow(text: "Play a card from your hand that matches the top discard by suit or rank.")
                        RuleRow(text: "You may play multiple cards of the same rank as a chain.")
                        RuleRow(text: "If you have nothing to play, tap Draw Card — you draw 1 card and your turn ends.")
                    }

                    RulesSection(title: "Special Cards") {
                        SpecialCardRow(card: "2 / 3", effect: "Forces the next player to draw 2 or 3 cards. Draw cards stack — add your own 2/3/Joker to increase the count.")
                        SpecialCardRow(card: "Joker", effect: "Forces the next player to draw 5 cards. Can stack with other draw cards.")
                        SpecialCardRow(card: "8 / Q", effect: "Question card — the next player must immediately play a card of the same suit, or draw 1 card.")
                        SpecialCardRow(card: "J (Jack)", effect: "Skips the next player's turn.")
                        SpecialCardRow(card: "K (King)", effect: "Reverses the direction of play.")
                        SpecialCardRow(card: "A (Ace)", effect: "Wild card — always playable. After playing, you choose the suit for the next player. The Ace of Spades (A♠) lets you demand a specific card.")
                    }

                    RulesSection(title: "Draw Stack") {
                        RuleRow(text: "If you face a draw stack (from 2s, 3s, or Jokers), you must tap Draw Stack to accept all the cards…")
                        RuleRow(text: "…unless you have a matching draw card to add to the stack, or an Ace to cancel it entirely.")
                    }

                    RulesSection(title: "Declaring KADI") {
                        RuleRow(text: "Tap the KADI button when you can empty your hand in one more play.")
                        RuleRow(text: "After declaring, you have one final turn to play out your remaining cards.")
                        RuleRow(text: "If you play again after declaring without going out, your declaration is cancelled and you may face a penalty.")
                        RuleRow(text: "If you go out without declaring, you get a penalty draw instead of winning.")
                    }

                    RulesSection(title: "Winning") {
                        RuleRow(text: "Empty your hand with a valid ending card (4–10 or King) while a KADI declaration is active.")
                        RuleRow(text: "Special cards (2, 3, Joker, J, Q, 8, Ace) cannot be the last card played to win.")
                    }
                }
                .padding(KadiTheme.Layout.spacingL)
            }
        }
        .navigationTitle("How to Play")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Sub-views

private struct RulesSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
            Text(title)
                .font(KadiTheme.Typography.headline)
                .foregroundStyle(KadiTheme.Colors.accent)

            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(KadiTheme.Layout.spacingM)
            .background(KadiTheme.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
        }
    }
}

private struct RuleRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: KadiTheme.Layout.spacingS) {
            Text("•")
                .foregroundStyle(KadiTheme.Colors.accent)
                .font(KadiTheme.Typography.body)
            Text(text)
                .font(KadiTheme.Typography.body)
                .foregroundStyle(KadiTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SpecialCardRow: View {
    let card: String
    let effect: String

    var body: some View {
        HStack(alignment: .top, spacing: KadiTheme.Layout.spacingM) {
            Text(card)
                .font(KadiTheme.Typography.callout)
                .foregroundStyle(KadiTheme.Colors.accent)
                .frame(width: 52, alignment: .leading)
                .fixedSize()
            Text(effect)
                .font(KadiTheme.Typography.body)
                .foregroundStyle(KadiTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        RulesView()
    }
}
