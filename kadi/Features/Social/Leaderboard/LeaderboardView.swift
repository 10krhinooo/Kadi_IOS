//
//  LeaderboardView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// Top players by `points`, per `docs/GAME_SPEC.md` §L. The current user's row is
/// highlighted with the accent color.
struct LeaderboardView: View {
    let authUser: AuthUser

    @StateObject private var viewModel = LeaderboardViewModel()

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            List {
                ForEach(Array(viewModel.players.enumerated()), id: \.element.uid) { index, player in
                    HStack(spacing: KadiTheme.Layout.spacingM) {
                        Text("\(index + 1)")
                            .font(KadiTheme.Typography.headline)
                            .foregroundStyle(KadiTheme.Colors.textSecondary)
                            .frame(width: 28, alignment: .leading)

                        AvatarView(avatarIndex: player.avatarId, size: 28)

                        Text(player.displayName)
                            .font(KadiTheme.Typography.body)
                            .foregroundStyle(KadiTheme.Colors.textPrimary)

                        Spacer()

                        Text("\(player.points)")
                            .font(KadiTheme.Typography.headline)
                            .foregroundStyle(KadiTheme.Colors.accent)
                    }
                    .listRowBackground(
                        player.uid == authUser.uid
                            ? KadiTheme.Colors.accent.opacity(0.15)
                            : KadiTheme.Colors.surface
                    )
                }
            }
            .scrollContentBackground(.hidden)

            if viewModel.isLoading && viewModel.players.isEmpty {
                ProgressView()
                    .tint(KadiTheme.Colors.accent)
            } else if !viewModel.isLoading && viewModel.players.isEmpty {
                Text("No players on the leaderboard yet.")
                    .font(KadiTheme.Typography.body)
                    .foregroundStyle(KadiTheme.Colors.textSecondary)
                    .padding(KadiTheme.Layout.spacingL)
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
