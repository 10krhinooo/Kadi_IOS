//
//  LANGuestLobbyViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiEngine
import KadiNetworking

/// Tracks the lobby roster for a joined `LANGameClient` and signals when the host has
/// started the game (or disappeared before doing so).
@MainActor
final class LANGuestLobbyViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var didStartGame = false
    @Published var hostLost = false
    @Published var localPlayerIndex: Int = 0
    private(set) var initialState: GameState?

    let client: LANGameClient

    private var rosterTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var hostLostTask: Task<Void, Never>?

    init(client: LANGameClient) {
        self.client = client
    }

    func start() {
        let client = self.client
        rosterTask = Task { [weak self] in
            for await roster in await client.rosterUpdates() {
                self?.players = roster
            }
        }
        stateTask = Task { [weak self] in
            for await newState in await client.gameStateUpdates() {
                guard let self, !self.didStartGame else { return }
                self.initialState = newState
                self.localPlayerIndex = await client.currentPlayerIndex ?? 0
                self.didStartGame = true
                return
            }
        }
        hostLostTask = Task { [weak self] in
            for await _ in await client.hostLostUpdates() {
                guard let self, !self.didStartGame else { return }
                self.hostLost = true
                return
            }
        }
    }

    func stop() {
        rosterTask?.cancel()
        stateTask?.cancel()
        hostLostTask?.cancel()
        let client = self.client
        Task { await client.stop() }
    }
}
