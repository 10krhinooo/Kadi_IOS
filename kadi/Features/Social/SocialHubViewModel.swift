//
//  SocialHubViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiOnline

@MainActor
final class SocialHubViewModel: ObservableObject {
    @Published private(set) var pendingRequestCount: Int = 0
    @Published private(set) var unreadMessageCount: Int = 0
    @Published private(set) var pendingInviteCount: Int = 0

    private let friendsService: FriendsService
    private let conversationService: ConversationService
    private let gameInviteService: GameInviteService
    private var requestsTask: Task<Void, Never>?
    private var conversationsTask: Task<Void, Never>?
    private var invitesTask: Task<Void, Never>?

    init(
        friendsService: FriendsService = FriendsService(),
        conversationService: ConversationService = ConversationService(),
        gameInviteService: GameInviteService = GameInviteService()
    ) {
        self.friendsService = friendsService
        self.conversationService = conversationService
        self.gameInviteService = gameInviteService
    }

    func start(authUser: AuthUser) {
        guard requestsTask == nil else { return }

        requestsTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await requests in self.friendsService.observeIncomingFriendRequests(uid: authUser.uid) {
                    self.pendingRequestCount = requests.count
                }
            } catch {
                // Badge is best-effort; ignore errors.
            }
        }

        conversationsTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await conversations in self.conversationService.observeConversations(uid: authUser.uid) {
                    self.unreadMessageCount = conversations.reduce(0) { $0 + ($1.unreadCounts[authUser.uid] ?? 0) }
                }
            } catch {
                // Badge is best-effort; ignore errors.
            }
        }

        invitesTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await invites in self.gameInviteService.observeIncomingInvites(uid: authUser.uid) {
                    self.pendingInviteCount = invites.count
                }
            } catch {
                // Badge is best-effort; ignore errors.
            }
        }
    }

    func stop() {
        requestsTask?.cancel()
        conversationsTask?.cancel()
        invitesTask?.cancel()
        requestsTask = nil
        conversationsTask = nil
        invitesTask = nil
    }
}
