//
//  ConversationsViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiOnline

@MainActor
final class ConversationsViewModel: ObservableObject {
    @Published private(set) var conversations: [DMConversation] = []
    @Published private(set) var profiles: [String: UserProfile] = [:]
    @Published var errorMessage: String?

    private let conversationService: ConversationService
    private let profileService: ProfileService
    private var task: Task<Void, Never>?

    init(conversationService: ConversationService = ConversationService(), profileService: ProfileService = ProfileService()) {
        self.conversationService = conversationService
        self.profileService = profileService
    }

    func start(authUser: AuthUser) {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                for try await conversations in self.conversationService.observeConversations(uid: authUser.uid) {
                    self.conversations = conversations
                    self.loadMissingProfiles(for: conversations, authUser: authUser)
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func otherUid(for conversation: DMConversation, authUser: AuthUser) -> String? {
        conversation.participants.first { $0 != authUser.uid }
    }

    func unreadCount(for conversation: DMConversation, authUser: AuthUser) -> Int {
        conversation.unreadCounts[authUser.uid] ?? 0
    }

    private func loadMissingProfiles(for conversations: [DMConversation], authUser: AuthUser) {
        let missingUids = conversations
            .compactMap { otherUid(for: $0, authUser: authUser) }
            .filter { profiles[$0] == nil }

        for uid in Set(missingUids) {
            Task { [weak self] in
                guard let self else { return }
                if let profile = try? await self.profileService.fetchProfile(uid: uid) {
                    self.profiles[uid] = profile
                }
            }
        }
    }
}
