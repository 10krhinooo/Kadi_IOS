//
//  OnlineGuestLobbyViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiEngine
import KadiOnline

/// Tracks the lobby roster for a room this device joined as a guest, and signals when
/// the host has started the game (or the room disappeared before it did).
@MainActor
final class OnlineGuestLobbyViewModel: ObservableObject {
    @Published var room: Room?
    @Published var didStartGame = false
    @Published var roomGone = false
    @Published var errorMessage: String?
    private(set) var initialState: GameState?

    let roomId: String
    let localPlayerIndex: Int
    let authUser: AuthUser

    private let roomService = RoomService()
    private var roomTask: Task<Void, Never>?

    init(roomId: String, localPlayerIndex: Int, authUser: AuthUser) {
        self.roomId = roomId
        self.localPlayerIndex = localPlayerIndex
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
                guard let self, !self.didStartGame else { return }
                self.roomGone = true
            } catch {
                guard let self, !self.didStartGame else { return }
                self.errorMessage = "\(error)"
                self.roomGone = true
            }
        }
    }

    func stop() {
        roomTask?.cancel()
        if !didStartGame {
            let roomService = self.roomService
            let roomId = self.roomId
            let uid = authUser.uid
            Task { try? await roomService.leaveRoom(roomId: roomId, uid: uid) }
        }
    }
}
