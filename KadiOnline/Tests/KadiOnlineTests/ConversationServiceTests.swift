import XCTest
@preconcurrency import FirebaseFirestore
@testable import KadiOnline

final class ConversationServiceTests: EmulatorTestCase {
    func testConversationIdIsDeterministicAndSorted() {
        XCTAssertEqual(ConversationService.conversationId(for: "uid-a", and: "uid-b"), "uid-a_uid-b")
        XCTAssertEqual(ConversationService.conversationId(for: "uid-b", and: "uid-a"), "uid-a_uid-b")
    }

    func testSendMessageUpdatesConversationAndUnreadCount() async throws {
        let service = ConversationService()
        try await service.sendMessage(senderUid: "uid-a", recipientUid: "uid-b", text: "hi")

        let convId = ConversationService.conversationId(for: "uid-a", and: "uid-b")
        let doc = try await Firestore.firestore().collection("conversations").document(convId).getDocument()
        let data = try XCTUnwrap(doc.data())
        XCTAssertEqual(data["participants"] as? [String], ["uid-a", "uid-b"])
        XCTAssertEqual(data["lastMessage"] as? String, "hi")
        XCTAssertNotNil(data["updatedAt"])

        let unreadCounts = try XCTUnwrap(data["unreadCounts"] as? [String: Int])
        XCTAssertEqual(unreadCounts["uid-b"], 1)
    }

    func testSendMessageIncrementsUnreadCountAcrossMessages() async throws {
        let service = ConversationService()
        try await service.sendMessage(senderUid: "uid-a", recipientUid: "uid-b", text: "one")
        try await service.sendMessage(senderUid: "uid-a", recipientUid: "uid-b", text: "two")

        let convId = ConversationService.conversationId(for: "uid-a", and: "uid-b")
        let doc = try await Firestore.firestore().collection("conversations").document(convId).getDocument()
        let unreadCounts = try XCTUnwrap(doc.data()?["unreadCounts"] as? [String: Int])
        XCTAssertEqual(unreadCounts["uid-b"], 2)
        XCTAssertEqual(doc.data()?["lastMessage"] as? String, "two")
    }

    func testSendMessageRejectsTooLongText() async throws {
        let service = ConversationService()
        let longText = String(repeating: "a", count: ConversationService.maxMessageLength + 1)

        do {
            try await service.sendMessage(senderUid: "uid-a", recipientUid: "uid-b", text: longText)
            XCTFail("expected messageTooLong error")
        } catch ConversationServiceError.messageTooLong {
            // expected
        }
    }

    func testObserveMessages() async throws {
        let service = ConversationService()
        try await service.sendMessage(senderUid: "uid-a", recipientUid: "uid-b", text: "hi")

        let convId = ConversationService.conversationId(for: "uid-a", and: "uid-b")
        let stream = service.observeMessages(convId: convId)
        for try await messages in stream {
            if let first = messages.first {
                XCTAssertEqual(first.senderUid, "uid-a")
                XCTAssertEqual(first.text, "hi")
                break
            }
        }
    }

    func testMarkReadResetsUnreadCount() async throws {
        let service = ConversationService()
        try await service.sendMessage(senderUid: "uid-a", recipientUid: "uid-b", text: "hi")

        let convId = ConversationService.conversationId(for: "uid-a", and: "uid-b")
        try await service.markRead(convId: convId, uid: "uid-b")

        let doc = try await Firestore.firestore().collection("conversations").document(convId).getDocument()
        let unreadCounts = try XCTUnwrap(doc.data()?["unreadCounts"] as? [String: Int])
        XCTAssertEqual(unreadCounts["uid-b"], 0)
    }

    func testObserveConversations() async throws {
        let service = ConversationService()
        try await service.sendMessage(senderUid: "uid-a", recipientUid: "uid-b", text: "hi")

        let stream = service.observeConversations(uid: "uid-b")
        for try await conversations in stream {
            if let first = conversations.first {
                XCTAssertEqual(first.participants, ["uid-a", "uid-b"])
                XCTAssertEqual(first.lastMessage, "hi")
                break
            }
        }
    }
}
