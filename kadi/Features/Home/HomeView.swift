//
//  HomeView.swift
//  kadi
//

import SwiftUI

struct HomeView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            ZStack {
                KadiTheme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: KadiTheme.Layout.spacingL) {
                    Spacer()

                    VStack(spacing: KadiTheme.Layout.spacingS) {
                        Text("KADI")
                            .font(KadiTheme.Typography.largeTitle)
                            .foregroundStyle(KadiTheme.Colors.accent)
                        Text("The classic card game")
                            .font(KadiTheme.Typography.body)
                            .foregroundStyle(KadiTheme.Colors.textSecondary)
                    }

                    Spacer()

                    VStack(spacing: KadiTheme.Layout.spacingM) {
                        NavigationLink {
                            SoloSetupView()
                        } label: {
                            Text("Solo Play")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        NavigationLink {
                            LANSetupView()
                        } label: {
                            Text("LAN Multiplayer")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        NavigationLink {
                            OnlineRootView()
                        } label: {
                            Text("Online Multiplayer")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        NavigationLink {
                            SocialRootView()
                        } label: {
                            Text("Profile")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        NavigationLink {
                            TutorialView()
                        } label: {
                            Text("Tutorial")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        NavigationLink {
                            RulesView()
                        } label: {
                            Text("How to Play")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.horizontal, KadiTheme.Layout.spacingL)

                    Spacer()
                }
            }
            .sheet(isPresented: $showOnboarding) {
                NavigationStack {
                    OnboardingView(isPresented: $showOnboarding)
                }
            }
            .onAppear {
                if !hasSeenOnboarding {
                    showOnboarding = true
                    hasSeenOnboarding = true
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
