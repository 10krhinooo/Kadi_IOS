//
//  GameInvitesView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// Incoming game invites, per `docs/GAME_SPEC.md` §L. Accepting joins the
/// room and navigates to `OnlineGuestLobbyView`; declining deletes the invite.
struct GameInvitesView: View {
    let authUser: AuthUser

    @StateObject private var viewModel = GameInvitesViewModel()

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(KadiTheme.Colors.accent)
            } else if viewModel.invites.isEmpty {
                Text("No pending game invites.")
                    .font(KadiTheme.Typography.body)
                    .foregroundStyle(KadiTheme.Colors.textSecondary)
                    .padding(KadiTheme.Layout.spacingL)
            } else {
                List(viewModel.invites, id: \.id) { invite in
                    VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                        Text(invite.fromName)
                            .font(KadiTheme.Typography.headline)
                            .foregroundStyle(KadiTheme.Colors.textPrimary)

                        Text("invited you to a game")
                            .font(KadiTheme.Typography.caption)
                            .foregroundStyle(KadiTheme.Colors.textSecondary)

                        HStack(spacing: KadiTheme.Layout.spacingM) {
                            Button("Accept") {
                                Task { await viewModel.accept(invite, authUser: authUser) }
                            }
                            .buttonStyle(PrimaryButtonStyle())

                            Button("Decline") {
                                Task { await viewModel.decline(invite) }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        .disabled(viewModel.isWorking)
                    }
                    .padding(.vertical, KadiTheme.Layout.spacingS)
                    .listRowBackground(KadiTheme.Colors.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Game Invites")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $viewModel.joinedRoom) { joinedRoom in
            OnlineGuestLobbyView(roomId: joinedRoom.roomId, localPlayerIndex: joinedRoom.playerIndex, authUser: authUser)
        }
        .task {
            viewModel.start(authUser: authUser)
        }
        .onDisappear {
            viewModel.stop()
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
