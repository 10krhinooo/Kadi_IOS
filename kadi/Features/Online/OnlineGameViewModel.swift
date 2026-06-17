//
//  OnlineGameViewModel.swift
//  kadi
//

import Combine
import Foundation
import SwiftUI
import KadiEngine
import KadiOnline

/// Drives an online multiplayer game for either the host or a guest, mirroring
/// `LANGameViewModel`'s shape. `state` only ever changes in response to
/// `RoomService.observeRoom`'s `gameState` field — local actions are validated for
/// instant "Invalid Move" feedback but never optimistically applied, so host and guest
/// always converge on the same state.
@MainActor
final class OnlineGameViewModel: ObservableObject {
    enum Role {
        case host(RoomHost)
        case guest(RoomClient)
    }

    @Published private(set) var state: GameState
    @Published var selectedCardIndices: Set<Int> = []
    @Published var errorMessage: String?

    private var isAutoActing = false

    let localPlayerIndex: Int
    let isHostRole: Bool

    private let role: Role
    private let roomService = RoomService()
    private let roomId: String
    private var roomTask: Task<Void, Never>?

    init(role: Role, localPlayerIndex: Int, initialState: GameState, roomId: String) {
        self.role = role
        self.localPlayerIndex = localPlayerIndex
        self.state = initialState
        self.roomId = roomId
        switch role {
        case .host:
            self.isHostRole = true
        case .guest:
            self.isHostRole = false
        }
        subscribe()
    }

    func stop() {
        roomTask?.cancel()
        if case .host(let host) = role {
            Task { await host.stop() }
        }
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
        guard state.phase == .playing && !state.isDrawStackActive else { return false }
        return KadiValidator.canDeclareKadi(
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
        let role = self.role
        Task {
            do {
                switch role {
                case .host(let host):
                    try await host.submitHostAction(action)
                case .guest(let client):
                    try await client.submitAction(action)
                }
            } catch {
                self.errorMessage = "\(error)"
            }
        }
    }

    private func checkAutoActions() {
        guard !isAutoActing, isLocalPlayerTurn, state.phase != .finished else { return }

        if state.isDrawStackActive {
            let hand = localPlayer.hand
            let rules = state.rules
            let hasCounter = hand.contains {
                let r = $0.rank
                if r == .two { return rules.twosEnabled }
                if r == .three { return rules.threesEnabled }
                return $0.isDrawCard
            } || hand.contains { $0.isAce }
            if !hasCounter {
                isAutoActing = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(1500))
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
                try? await Task.sleep(for: .milliseconds(1500))
                guard let self, self.isAutoActing else { return }
                self.isAutoActing = false
                self.pass()
            }
        }
    }

    // MARK: - Subscriptions

    private func subscribe() {
        let roomService = self.roomService
        let roomId = self.roomId
        roomTask = Task { [weak self] in
            do {
                for try await room in roomService.observeRoom(roomId: roomId) {
                    guard let self else { return }
                    if let gameState = room.gameState {
                        self.state = gameState
                        self.selectedCardIndices = []
                        self.checkAutoActions()
                    }
                }
            } catch {
                guard let self else { return }
                self.errorMessage = "\(error)"
            }
        }
    }
}
