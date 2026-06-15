//
//  GameInvitesViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiOnline

@MainActor
final class GameInvitesViewModel: ObservableObject {
    @Published private(set) var invites: [GameInvite] = []
    @Published private(set) var isLoading = true
    @Published var joinedRoom: JoinedRoom?
    @Published var isWorking = false
    @Published var errorMessage: String?

    struct JoinedRoom: Identifiable, Hashable {
        let roomId: String
        let playerIndex: Int
        var id: String { roomId }
    }

    private let gameInviteService: GameInviteService
    private let roomService: RoomService
    private let identity = PlayerIdentityStore()
    private var task: Task<Void, Never>?

    init(gameInviteService: GameInviteService = GameInviteService(), roomService: RoomService = RoomService()) {
        self.gameInviteService = gameInviteService
        self.roomService = roomService
    }

    func start(authUser: AuthUser) {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                for try await invites in self.gameInviteService.observeIncomingInvites(uid: authUser.uid) {
                    self.invites = invites
                    self.isLoading = false
                }
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func accept(_ invite: GameInvite, authUser: AuthUser) async {
        isWorking = true
        defer { isWorking = false }

        do {
            let playerIndex = try await roomService.joinRoom(roomId: invite.roomId, uid: authUser.uid, name: identity.name)
            joinedRoom = JoinedRoom(roomId: invite.roomId, playerIndex: playerIndex)
            if let inviteId = invite.id {
                try? await gameInviteService.deleteInvite(inviteId: inviteId)
            }
        } catch RoomServiceError.roomNotFound {
            errorMessage = "That room no longer exists."
        } catch RoomServiceError.roomFull {
            errorMessage = "That room is full."
        } catch RoomServiceError.roomAlreadyStarted {
            errorMessage = "That game has already started."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func decline(_ invite: GameInvite) async {
        guard let inviteId = invite.id else { return }
        do {
            try await gameInviteService.deleteInvite(inviteId: inviteId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
