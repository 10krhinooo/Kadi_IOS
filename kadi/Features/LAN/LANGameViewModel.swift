//
//  LANGameViewModel.swift
//  kadi
//

import Combine
import Foundation
import SwiftUI
import KadiEngine
import KadiNetworking

/// Drives a LAN multiplayer game for either the host or a guest, mirroring
/// `SoloGameViewModel`'s shape. `state` only ever changes in response to a broadcast
/// `GameState` from `session.gameStateUpdates()` — local actions are validated for instant
/// "Invalid Move" feedback but never optimistically applied, so host and guest always
/// converge on the same state.
@MainActor
final class LANGameViewModel: ObservableObject {
    enum Role {
        case host(LANGameHost)
        case guest(LANGameClient)
    }

    enum MigrationState: Equatable {
        case none
        case hostLostPromoting
        case hostLostReconnecting
        case reconnectFailed
    }

    @Published private(set) var state: GameState
    @Published var selectedCardIndices: Set<Int> = []
    @Published var errorMessage: String?
    @Published var disconnectedPlayerIndices: Set<Int> = []
    @Published var migrationState: MigrationState = .none
    @Published var migrationMessage: String?

    private var isAutoActing = false

    let localPlayerIndex: Int
    private(set) var isHostRole: Bool
    private var session: any LANGameSession
    private let rules: RuleSet
    private let gameName: String

    private var stateTask: Task<Void, Never>?
    private var connectionEventTask: Task<Void, Never>?
    private var hostLostTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    init(role: Role, localPlayerIndex: Int, initialState: GameState, rules: RuleSet, gameName: String) {
        self.localPlayerIndex = localPlayerIndex
        self.state = initialState
        self.rules = rules
        self.gameName = gameName
        switch role {
        case .host(let host):
            self.session = host
            self.isHostRole = true
        case .guest(let client):
            self.session = client
            self.isHostRole = false
        }
        subscribe()
    }

    func stop() {
        stateTask?.cancel()
        connectionEventTask?.cancel()
        hostLostTask?.cancel()
        reconnectTask?.cancel()
        let session = self.session
        Task { await session.stop() }
    }

    // MARK: - Derived state

    var localPlayer: Player { state.players[localPlayerIndex] }

    var playableCards: [PlayingCard] {
        KadiValidator.validPlays(
            hand: localPlayer.hand,
            topCard: state.topCard,
            forcedSuit: state.forcedSuit,
            rules: state.rules
        )
    }

    var playableIndices: Set<Int> {
        let playable = playableCards
        var result: Set<Int> = []
        for (index, card) in localPlayer.hand.enumerated() where playable.contains(card) {
            result.insert(index)
        }
        return result
    }

    var canDeclareKadi: Bool {
        KadiValidator.canDeclareKadi(
            hand: localPlayer.hand,
            topCard: state.topCard,
            forcedSuit: state.forcedSuit,
            rules: state.rules
        )
    }

    var isLocalPlayerTurn: Bool {
        state.currentPlayerIndex == localPlayerIndex
    }

    var winner: Player? {
        guard state.phase == .finished else { return nil }
        return state.players.first { $0.hand.isEmpty }
    }

    // MARK: - Local actions

    func toggleSelection(at index: Int) {
        if selectedCardIndices.contains(index) {
            selectedCardIndices.remove(index)
        } else {
            selectedCardIndices.insert(index)
        }
    }

    func confirmPlaySelected() {
        perform(.playCards(cards: selectedCards()))
    }

    func pass() {
        perform(.pass)
    }

    func drawStack() {
        perform(.drawStack)
    }

    func declareKadi() {
        perform(.declareKadi(cards: selectedCards()))
    }

    func chooseSuit(_ suit: Suit) {
        perform(.chooseSuit(suit: suit))
    }

    func makeDemand(rank: Rank, suit: Suit) {
        perform(.makeDemand(rank: rank, suit: suit))
    }

    func respondToDemand(card: PlayingCard?) {
        perform(.respondToDemand(card: card))
    }

    func interceptSkip(jacks: [PlayingCard]) {
        perform(.interceptSkip(jacks: jacks))
    }

    func declineIntercept() {
        perform(.declineIntercept)
    }

    private func selectedCards() -> [PlayingCard] {
        selectedCardIndices.sorted().map { localPlayer.hand[$0] }
    }

    // MARK: - Action submission

    private func perform(_ action: GameAction) {
        isAutoActing = false
        if let error = GameEngine.validateAction(state, action) {
            errorMessage = error
            return
        }
        selectedCardIndices = []
        let session = self.session
        Task {
            do {
                try await session.submitAction(action)
            } catch {
                self.errorMessage = "\(error)"
            }
        }
    }

    private func checkAutoActions() {
        guard !isAutoActing, isLocalPlayerTurn, state.phase != .finished else { return }

        if state.isDrawStackActive {
            let hand = localPlayer.hand
            let hasCounter = hand.contains { $0.isDrawCard } || hand.contains { $0.isAce }
            if !hasCounter {
                isAutoActing = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(700))
                    guard let self, self.isAutoActing else { return }
                    self.isAutoActing = false
                    self.drawStack()
                }
                return
            }
        }

        if (state.phase == .playing || state.phase == .questionAnswer), playableIndices.isEmpty {
            isAutoActing = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                guard let self, self.isAutoActing else { return }
                self.isAutoActing = false
                self.pass()
            }
        }
    }

    // MARK: - Subscriptions

    private func subscribe() {
        let session = self.session

        stateTask = Task { [weak self] in
            for await newState in await session.gameStateUpdates() {
                guard let self else { return }
                self.state = newState
                self.selectedCardIndices = []
                self.checkAutoActions()
            }
        }

        connectionEventTask = Task { [weak self] in
            for await event in await session.connectionEvents() {
                guard let self else { return }
                switch event {
                case .playerDisconnected(let playerIndex):
                    self.disconnectedPlayerIndices.insert(playerIndex)
                case .playerReconnected(let playerIndex):
                    self.disconnectedPlayerIndices.remove(playerIndex)
                }
            }
        }

        if case .guest(let client) = currentRole() {
            hostLostTask = Task { [weak self] in
                for await _ in await client.hostLostUpdates() {
                    guard let self else { return }
                    await self.handleHostLost(client: client)
                    return
                }
            }
        }
    }

    private func currentRole() -> Role {
        if let client = session as? LANGameClient {
            return .guest(client)
        }
        if let host = session as? LANGameHost {
            return .host(host)
        }
        fatalError("Unknown LANGameSession implementation")
    }

    // MARK: - Host migration

    private func handleHostLost(client: LANGameClient) async {
        // Stagger promotion checks by seat index so that, when multiple clients lose the
        // host near-simultaneously, lower-indexed seats are more likely to have already
        // promoted (and relayed playerDisconnected updates) before higher-indexed seats
        // evaluate isLowestSurvivingPlayerIndex — reducing (not eliminating) the chance of
        // two clients both promoting to host.
        if let myIndex = await client.currentPlayerIndex, myIndex > 1 {
            try? await Task.sleep(for: .seconds(Double(myIndex - 1) * 0.5))
        }
        if await client.isLowestSurvivingPlayerIndex() {
            migrationState = .hostLostPromoting
            migrationMessage = "Taking over as host…"
            do {
                let newHost = try await client.promoteToHost(gameName: gameName, rules: rules)
                stateTask?.cancel()
                connectionEventTask?.cancel()
                hostLostTask?.cancel()
                session = newHost
                isHostRole = true
                migrationState = .none
                migrationMessage = nil
                subscribe()
            } catch {
                migrationState = .reconnectFailed
                migrationMessage = "Failed to take over as host."
            }
        } else {
            await attemptReconnect(client: client)
        }
    }

    private func attemptReconnect(client: LANGameClient) async {
        migrationState = .hostLostReconnecting
        migrationMessage = "Searching for new host…"

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            let browser = LANBrowser()
            let timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard let self, !Task.isCancelled else { return }
                if self.migrationState == .hostLostReconnecting {
                    self.migrationState = .reconnectFailed
                    self.migrationMessage = "Couldn't find the new host."
                    self.reconnectTask?.cancel()
                }
            }
            for await discovered in await browser.discoveredHosts() {
                guard discovered.name == self.gameName else { continue }
                timeoutTask.cancel()
                do {
                    try await client.reconnect(to: discovered.endpoint)
                    self.migrationState = .none
                    self.migrationMessage = nil
                } catch {
                    self.migrationState = .reconnectFailed
                    self.migrationMessage = "Failed to reconnect to the new host."
                }
                break
            }
            await browser.stop()
        }
    }

    /// Retries the reconnect-to-new-host flow after `.reconnectFailed`. No-op for the host
    /// role or while a reconnect attempt is already in progress.
    func retryReconnect() {
        guard !isHostRole, case .guest(let client) = currentRole() else { return }
        Task { await attemptReconnect(client: client) }
    }
}
