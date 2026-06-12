import XCTest
@testable import KadiOnline

final class QuickChatServiceTests: EmulatorTestCase {
    func testSendQuickChatWritesMessage() async throws {
        let service = QuickChatService()
        try await service.sendQuickChat(roomId: "ABCDEF", uid: "uid-a", message: "gg")

        let stream = service.observeQuickChat(roomId: "ABCDEF")
        for try await messages in stream {
            if let first = messages.first {
                XCTAssertEqual(first.uid, "uid-a")
                XCTAssertEqual(first.message, "gg")
                XCTAssertNotNil(first.timestamp)
                break
            }
        }
    }

    func testSendQuickChatOverwritesPreviousMessage() async throws {
        let service = QuickChatService()
        try await service.sendQuickChat(roomId: "ABCDEF", uid: "uid-a", message: "first")
        try await service.sendQuickChat(roomId: "ABCDEF", uid: "uid-a", message: "second")

        let stream = service.observeQuickChat(roomId: "ABCDEF")
        for try await messages in stream {
            if messages.count == 1, let first = messages.first {
                XCTAssertEqual(first.message, "second")
                break
            }
        }
    }

    func testObserveQuickChatReturnsOneMessagePerPlayer() async throws {
        let service = QuickChatService()
        try await service.sendQuickChat(roomId: "ABCDEF", uid: "uid-a", message: "gg")
        try await service.sendQuickChat(roomId: "ABCDEF", uid: "uid-b", message: "good luck")

        let stream = service.observeQuickChat(roomId: "ABCDEF")
        for try await messages in stream {
            if messages.count == 2 {
                let byUid = Dictionary(uniqueKeysWithValues: messages.map { ($0.uid, $0.message) })
                XCTAssertEqual(byUid["uid-a"], "gg")
                XCTAssertEqual(byUid["uid-b"], "good luck")
                break
            }
        }
    }

    func testClearQuickChatRemovesAllMessages() async throws {
        let service = QuickChatService()
        try await service.sendQuickChat(roomId: "ABCDEF", uid: "uid-a", message: "gg")
        try await service.clearQuickChat(roomId: "ABCDEF")

        let stream = service.observeQuickChat(roomId: "ABCDEF")
        for try await messages in stream {
            XCTAssertTrue(messages.isEmpty)
            break
        }
    }
}
