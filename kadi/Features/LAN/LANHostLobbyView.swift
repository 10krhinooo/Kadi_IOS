//
//  LANHostLobbyView.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Lobby shown to the host while waiting for guests to join. Lets the host start the
/// game once at least one other player has joined.
struct LANHostLobbyView: View {
    @StateObject private var viewModel: LANHostLobbyViewModel

    init(identity: PlayerIdentityStore) {
        _viewModel = StateObject(wrappedValue: LANHostLobbyViewModel(identity: identity))
    }

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingL) {
                VStack(spacing: KadiTheme.Layout.spacingS) {
                    Text("Hosting")
                        .font(KadiTheme.Typography.title)
                        .foregroundStyle(KadiTheme.Colors.textPrimary)
                    Text(viewModel.gameName)
                        .font(KadiTheme.Typography.body)
                        .foregroundStyle(KadiTheme.Colors.textSecondary)
                }
                .padding(.top, KadiTheme.Layout.spacingL)

                VStack(spacing: 0) {
                    ForEach(Array(viewModel.players.enumerated()), id: \.offset) { index, player in
                        LobbyPlayerRowView(
                            name: player.name,
                            avatarIndex: player.avatarIndex,
                            isHost: index == 0,
                            isYou: index == 0
                        )
                    }
                }
                .padding(KadiTheme.Layout.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius)
                        .fill(KadiTheme.Colors.surface.opacity(0.5))
                )

                Spacer()

                Text(viewModel.canStartGame ? "Ready to start" : "Waiting for at least one more player…")
                    .font(KadiTheme.Typography.callout)
                    .foregroundStyle(KadiTheme.Colors.textSecondary)

                Button("Start Game") {
                    viewModel.startGame()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!viewModel.canStartGame)
            }
            .padding(KadiTheme.Layout.spacingL)
        }
        .navigationTitle("Lobby")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.start() }
        .onDisappear {
            if !viewModel.didStartGame {
                viewModel.stop()
            }
        }
        .navigationDestination(isPresented: $viewModel.didStartGame) {
            if let initialState = viewModel.initialState {
                LANGameView(
                    role: .host(viewModel.host),
                    localPlayerIndex: 0,
                    initialState: initialState,
                    rules: viewModel.rules,
                    gameName: viewModel.gameName
                )
            }
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
