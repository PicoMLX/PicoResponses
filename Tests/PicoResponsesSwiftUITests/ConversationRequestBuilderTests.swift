import XCTest
@testable import PicoResponsesSwiftUI

final class ConversationRequestBuilderTests: XCTestCase {
    func testBuilderAppliesTemperatureAndPenalties() {
        var builder = ConversationRequestBuilder(
            model: "gpt-4.1-mini",
            temperature: 0.6,
            topP: 0.9,
            frequencyPenalty: 0.2,
            presencePenalty: 0.1,
            maxOutputTokens: 512
        )
        builder.instructions = "You are a helpful assistant."

        let message = ConversationMessage(role: .user, text: "Hello")
        let request = builder.makeRequest(from: [message], previousResponseId: "resp_123")

        XCTAssertEqual(request.model, "gpt-4.1-mini")
        XCTAssertEqual(request.temperature, 0.6)
        XCTAssertEqual(request.topP, 0.9)
        XCTAssertEqual(request.frequencyPenalty, 0.2)
        XCTAssertEqual(request.presencePenalty, 0.1)
        XCTAssertEqual(request.maxOutputTokens, 512)
        XCTAssertEqual(request.instructions, "You are a helpful assistant.")
        XCTAssertEqual(request.previousResponseId, "resp_123")
    }

    func testLatestMessageStrategySendsSingleMessage() {
        let builder = ConversationRequestBuilder(model: "gpt-4.1-mini")
        let history: [ConversationMessage] = [
            ConversationMessage(role: .user, text: "Hello"),
            ConversationMessage(role: .assistant, text: "Hi there"),
            ConversationMessage(role: .user, text: "Why is the sky blue?")
        ]

        let request = builder.makeRequest(from: history, previousResponseId: "resp_456")

        XCTAssertEqual(request.input.count, 1)
        guard let first = request.input.first else {
            XCTFail("Missing input item")
            return
        }
        guard case let .message(message) = first else {
            XCTFail("Expected message input")
            return
        }
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content.first?.text, "Why is the sky blue?")
        XCTAssertEqual(request.previousResponseId, "resp_456")
    }

    func testFullConversationStrategyRetainsAllMessages() {
        let builder = ConversationRequestBuilder(
            model: "gpt-4.1-mini",
            historyStrategy: .fullConversation
        )
        let history: [ConversationMessage] = [
            ConversationMessage(role: .user, text: "One"),
            ConversationMessage(role: .assistant, text: "Two"),
            ConversationMessage(role: .user, text: "Three")
        ]

        let request = builder.makeRequest(from: history, previousResponseId: nil)

        XCTAssertEqual(request.input.count, 3)
    }
}
