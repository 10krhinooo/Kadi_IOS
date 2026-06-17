//
//  OnboardingView.swift
//  kadi
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var page = 0

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    OnboardingPage(
                        systemImage: "suit.spade.fill",
                        title: "Welcome to Kadi",
                        text: "The fast-paced East African card game. Empty your hand before anyone else — but you'll need to shout KADI first!"
                    ).tag(0)

                    OnboardingPage(
                        systemImage: "rectangle.stack.fill",
                        title: "How It Works",
                        text: "Match the top card by suit or rank to play. Special cards shake things up: 2s and 3s force draws, Jacks skip turns, Kings reverse direction, and Aces are wild."
                    ).tag(1)

                    OnboardingPage(
                        systemImage: "star.fill",
                        title: "Ready?",
                        text: "Play through the tutorial to learn every rule in a live game, or jump straight in."
                    ).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                if page == 2 {
                    VStack(spacing: KadiTheme.Layout.spacingS) {
                        NavigationLink {
                            TutorialView(onDismiss: { isPresented = false })
                        } label: {
                            Text("Start Tutorial")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("Skip") { isPresented = false }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.horizontal, KadiTheme.Layout.spacingL)
                    .padding(.bottom, KadiTheme.Layout.spacingL)
                } else {
                    Button("Next") { withAnimation { page += 1 } }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, KadiTheme.Layout.spacingL)
                        .padding(.bottom, KadiTheme.Layout.spacingL)
                }
            }
        }
    }
}

private struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: KadiTheme.Layout.spacingL) {
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundStyle(KadiTheme.Colors.accent)
                .padding(.top, KadiTheme.Layout.spacingL)

            Text(title)
                .font(KadiTheme.Typography.largeTitle)
                .foregroundStyle(KadiTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(text)
                .font(KadiTheme.Typography.body)
                .foregroundStyle(KadiTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KadiTheme.Layout.spacingL)

            Spacer()
        }
    }
}
