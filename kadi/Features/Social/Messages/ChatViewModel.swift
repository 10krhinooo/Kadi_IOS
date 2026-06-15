//
//  ChatViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiOnline

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [DMMessage] = []
    @Published var draftText: String = ""
    @Published var errorMessage: String?

    private let conversationService: ConversationService
    private var task: Task<Void, Never>?

    init(conversationService: ConversationService = ConversationService()) {
        self.conversationService = conversationService
    }

    func start(authUser: AuthUser, otherUid: String) {
        guard task == nil else { return }
        let convId = ConversationService.conversationId(for: authUser.uid, and: otherUid)

        task = Task { [weak self] in
            guard let self else { return }
            do {
                for try await messages in self.conversationService.observeMessages(convId: convId) {
                    self.messages = messages
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }

        Task {
            try? await conversationService.markRead(convId: convId, uid: authUser.uid)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func send(authUser: AuthUser, otherUid: String) async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        do {
            try await conversationService.sendMessage(senderUid: authUser.uid, recipientUid: otherUid, text: text)
            draftText = ""
        } catch ConversationServiceError.messageTooLong {
            errorMessage = "Message is too long (max \(ConversationService.maxMessageLength) characters)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
