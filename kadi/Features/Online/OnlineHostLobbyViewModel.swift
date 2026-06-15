//
//  OnlineHostLobbyViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiEngine
import KadiOnline

/// Owns the lobby for a room this device created: observes the roster via
/// `RoomService.observeRoom`, and on "Start Game" creates a `RoomHost`, starts the game,
/// and begins processing guest actions.
@MainActor
final class OnlineHostLobbyViewModel: ObservableObject {
    @Published var room: Room?
    @Published var didStartGame = false
    @Published var errorMessage: String?
    private(set) var initialState: GameState?
    private(set) var roomHost: RoomHost?

    let roomId: String
    let authUser: AuthUser

    private let roomService = RoomService()
    private let gameInviteService = GameInviteService()
    private let identity = PlayerIdentityStore()
    private var roomTask: Task<Void, Never>?

    var canStartGame: Bool { (room?.players.count ?? 0) >= 2 }

    init(roomId: String, authUser: AuthUser) {
        self.roomId = roomId
        self.authUser = authUser
    }

    func start() {
        let roomService = self.roomService
        let roomId = self.roomId
        roomTask = Task { [weak self] in
            do {
                for try await room in roomService.observeRoom(roomId: roomId) {
                    guard let self else { return }
                    self.room = room
                    if !self.didStartGame, room.status == .playing, let gameState = room.gameState {
                        self.initialState = gameState
                        self.didStartGame = true
                    }
                }
            } catch {
                guard let self else { return }
                self.errorMessage = "\(error)"
            }
        }
    }

    func startGame() {
        guard let room else { return }
        let roomHost = RoomHost(
            roomId: roomId,
            hostUid: authUser.uid,
            players: room.players,
            rules: room.rules
        )
        self.roomHost = roomHost
        Task {
            do {
                try await roomHost.startGame()
                await roomHost.startProcessingActions()
            } catch {
                self.errorMessage = "\(error)"
            }
        }
    }

    func sendInvite(to friend: Friend) async {
        do {
            _ = try await gameInviteService.sendInvite(
                fromUid: authUser.uid,
                fromName: identity.name,
                toUid: friend.uid,
                roomId: roomId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        roomTask?.cancel()
        if !didStartGame {
            let roomService = self.roomService
            let roomId = self.roomId
            Task { try? await roomService.deleteRoom(roomId: roomId) }
        }
    }
}
