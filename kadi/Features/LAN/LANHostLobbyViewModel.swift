//
//  LANHostLobbyViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiEngine
import KadiNetworking

/// Owns a `LANGameHost` for the local player's lobby: advertises the game, tracks the
/// joined roster, and signals when the host has started the game.
@MainActor
final class LANHostLobbyViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var didStartGame = false
    @Published var errorMessage: String?
    private(set) var initialState: GameState?

    let host: LANGameHost
    let rules: RuleSet
    let gameName: String

    private var lobbyTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?

    var canStartGame: Bool { players.count >= 2 }

    init(identity: PlayerIdentityStore, rules: RuleSet = RuleSet()) {
        self.rules = rules
        self.gameName = "\(identity.name)'s Game"
        self.host = LANGameHost(
            hostName: identity.name,
            hostUid: identity.uid,
            hostAvatarIndex: identity.avatarIndex,
            rules: rules
        )
    }

    func start() {
        let host = self.host
        let gameName = self.gameName
        Task {
            do {
                try await host.start(gameName: gameName)
            } catch {
                self.errorMessage = "\(error)"
            }
        }
        lobbyTask = Task { [weak self] in
            for await roster in await host.lobbyUpdates() {
                self?.players = roster
            }
        }
        stateTask = Task { [weak self] in
            for await newState in await host.gameStateUpdates() {
                guard let self, !self.didStartGame else { return }
                self.initialState = newState
                self.didStartGame = true
                return
            }
        }
    }

    func startGame() {
        let host = self.host
        Task {
            do {
                try await host.startGame()
            } catch {
                self.errorMessage = "\(error)"
            }
        }
    }

    func stop() {
        lobbyTask?.cancel()
        stateTask?.cancel()
        let host = self.host
        Task { await host.stop() }
    }
}
