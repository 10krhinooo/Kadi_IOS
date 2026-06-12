//
//  SoloSetupView.swift
//  kadi
//

import SwiftUI

struct SoloSetupView: View {
    @State private var opponentCount: Int = 1
    @State private var difficulty: CpuDifficulty = .medium

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingL) {
                Text("Solo Play")
                    .font(KadiTheme.Typography.title)
                    .foregroundStyle(KadiTheme.Colors.textPrimary)
                    .padding(.top, KadiTheme.Layout.spacingL)

                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                    Text("Opponents")
                        .font(KadiTheme.Typography.headline)
                        .foregroundStyle(KadiTheme.Colors.textPrimary)

                    Picker("Opponents", selection: $opponentCount) {
                        ForEach(1...3, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                    Text("Difficulty")
                        .font(KadiTheme.Typography.headline)
                        .foregroundStyle(KadiTheme.Colors.textPrimary)

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(CpuDifficulty.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Spacer()

                NavigationLink {
                    SoloGameView(opponentCount: opponentCount, difficulty: difficulty)
                } label: {
                    Text("Start Game")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(KadiTheme.Layout.spacingL)
        }
        .navigationTitle("Solo Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SoloSetupView()
    }
}
