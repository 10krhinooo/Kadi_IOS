import XCTest
@testable import KadiNetworking

final class NDJSONFramerTests: XCTestCase {
    func testEncodeProducesNewlineTerminatedJSON() throws {
        let data = try NDJSONFramer.encode(.ping)
        XCTAssertEqual(data.last, 0x0A)

        let jsonData = data.dropLast()
        let object = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertEqual(object?["type"] as? String, "ping")
        XCTAssertEqual(object?["payload"] as? [String: String], [:])
    }

    func testFeedSingleCompleteLine() throws {
        var buffer = NDJSONLineBuffer()
        let data = try NDJSONFramer.encode(.ping)
        let messages = try buffer.feed(data)
        XCTAssertEqual(messages, [.ping])
    }

    func testFeedMultipleMessagesInOneChunk() throws {
        var buffer = NDJSONLineBuffer()
        var combined = Data()
        combined.append(try NDJSONFramer.encode(.ping))
        combined.append(try NDJSONFramer.encode(.pong))
        combined.append(try NDJSONFramer.encode(.playerAction(.declineIntercept)))

        let messages = try buffer.feed(combined)
        XCTAssertEqual(messages, [.ping, .pong, .playerAction(.declineIntercept)])
    }

    func testFeedPartialLineAcrossChunks() throws {
        var buffer = NDJSONLineBuffer()
        let full = try NDJSONFramer.encode(.playerAction(.pass))
        let splitPoint = full.count / 2
        let firstHalf = full.prefix(splitPoint)
        let secondHalf = full.suffix(from: splitPoint)

        let firstMessages = try buffer.feed(Data(firstHalf))
        XCTAssertTrue(firstMessages.isEmpty)

        let secondMessages = try buffer.feed(Data(secondHalf))
        XCTAssertEqual(secondMessages, [.playerAction(.pass)])
    }

    func testFeedRetainsTrailingPartialLine() throws {
        var buffer = NDJSONLineBuffer()
        var combined = try NDJSONFramer.encode(.ping)
        let partial = try NDJSONFramer.encode(.pong)
        combined.append(partial.prefix(partial.count - 1))

        let messages = try buffer.feed(combined)
        XCTAssertEqual(messages, [.ping])

        // Completing the partial line with the missing newline should now decode.
        let finalMessages = try buffer.feed(Data([0x0A]))
        XCTAssertEqual(finalMessages, [.pong])
    }
}
