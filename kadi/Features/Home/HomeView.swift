//
//  HomeView.swift
//  kadi
//

import SwiftUI

struct HomeView: View {
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

                        Button("Online Multiplayer") {}
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(true)
                            .opacity(0.4)

                        Button("Profile") {}
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(true)
                            .opacity(0.4)
                    }
                    .padding(.horizontal, KadiTheme.Layout.spacingL)

                    Spacer()
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
