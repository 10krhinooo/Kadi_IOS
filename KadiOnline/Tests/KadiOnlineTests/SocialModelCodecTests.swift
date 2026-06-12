import XCTest
import KadiEngine
@testable import KadiOnline

final class SocialModelCodecTests: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    func testFriendRoundTrip() throws {
        let friend = Friend(uid: "friend-uid", displayName: "Friend", avatarId: 3, since: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try encoder.encode(friend)
        let decoded = try decoder.decode(Friend.self, from: data)
        XCTAssertEqual(decoded, friend)
    }

    func testFriendRequestRoundTrip() throws {
        let request = FriendRequest(
            fromUid: "from-uid",
            fromName: "From",
            fromAvatarId: 1,
            toUid: "to-uid",
            status: .pending,
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(FriendRequest.self, from: data)
        XCTAssertEqual(decoded.fromUid, request.fromUid)
        XCTAssertEqual(decoded.fromName, request.fromName)
        XCTAssertEqual(decoded.fromAvatarId, request.fromAvatarId)
        XCTAssertEqual(decoded.toUid, request.toUid)
        XCTAssertEqual(decoded.status, request.status)
        XCTAssertEqual(decoded.createdAt, request.createdAt)
    }

    func testBlockedUserRoundTrip() throws {
        let blocked = BlockedUser(uid: "target-uid", blockedAt: Date(timeIntervalSince1970: 1_700_000_200))
        let data = try encoder.encode(blocked)
        let decoded = try decoder.decode(BlockedUser.self, from: data)
        XCTAssertEqual(decoded, blocked)
    }

    func testDMConversationRoundTrip() throws {
        let conversation = DMConversation(
            participants: ["uid-a", "uid-b"],
            lastMessage: "hi",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_300),
            unreadCounts: ["uid-a": 0, "uid-b": 1]
        )
        let data = try encoder.encode(conversation)
        let decoded = try decoder.decode(DMConversation.self, from: data)
        XCTAssertEqual(decoded, conversation)
    }

    func testDMMessageRoundTrip() throws {
        let message = DMMessage(senderUid: "uid-a", text: "hi", timestamp: Date(timeIntervalSince1970: 1_700_000_400))
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(DMMessage.self, from: data)
        XCTAssertEqual(decoded, message)
    }

    func testGameInviteRoundTrip() throws {
        let invite = GameInvite(
            fromUid: "from-uid",
            fromName: "From",
            toUid: "to-uid",
            roomId: "ABCDEF",
            createdAt: Date(timeIntervalSince1970: 1_700_000_500),
            expiresAt: Date(timeIntervalSince1970: 1_700_003_600)
        )
        let data = try encoder.encode(invite)
        let decoded = try decoder.decode(GameInvite.self, from: data)
        XCTAssertEqual(decoded.fromUid, invite.fromUid)
        XCTAssertEqual(decoded.fromName, invite.fromName)
        XCTAssertEqual(decoded.toUid, invite.toUid)
        XCTAssertEqual(decoded.roomId, invite.roomId)
        XCTAssertEqual(decoded.createdAt, invite.createdAt)
        XCTAssertEqual(decoded.expiresAt, invite.expiresAt)
    }

    func testReportRoundTrip() throws {
        let report = Report(reporterUid: "reporter-uid", targetUid: "target-uid", reason: "spam", createdAt: Date(timeIntervalSince1970: 1_700_000_600))
        let data = try encoder.encode(report)
        let decoded = try decoder.decode(Report.self, from: data)
        XCTAssertEqual(decoded, report)
    }

    func testSavedRuleSetRoundTrip() throws {
        let saved = SavedRuleSet(name: "My Rules", rules: RuleSet(), createdAt: Date(timeIntervalSince1970: 1_700_000_700))
        let data = try encoder.encode(saved)
        let decoded = try decoder.decode(SavedRuleSet.self, from: data)
        XCTAssertEqual(decoded.name, saved.name)
        XCTAssertEqual(decoded.rules, saved.rules)
        XCTAssertEqual(decoded.createdAt, saved.createdAt)
    }
}
