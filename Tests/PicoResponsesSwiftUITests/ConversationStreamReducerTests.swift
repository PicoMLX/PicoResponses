import XCTest
@testable import PicoResponsesSwiftUI
import PicoResponsesCore

final class ConversationStreamReducerTests: XCTestCase {
    func testDeltaAppendsAssistantMessage() {
        var snapshot = ConversationStateSnapshot(
            messages: [ConversationMessage(role: .user, text: "Hello")],
            responsePhase: .awaitingResponse
        )

        let event = ResponseStreamEvent(
            type: "response.output_text.delta",
            data: Self.makeEventData([
                "delta": [
                    "text": " world"
                ]
            ])
        )

        snapshot = ConversationStreamReducer.reduce(snapshot: snapshot, with: event)

        XCTAssertEqual(snapshot.messages.last?.role, .assistant)
        XCTAssertEqual(snapshot.messages.last?.text, " world")
        XCTAssertTrue(snapshot.responsePhase.isStreaming)
    }

    func testCompletedResponseReplacesAssistantMessage() throws {
        var snapshot = ConversationStateSnapshot(
            messages: [
                ConversationMessage(role: .user, text: "Hi"),
                ConversationMessage(role: .assistant, text: "partial")
            ],
            responsePhase: .streaming
        )

        let response = ResponseObject(
            id: "resp_1",
            createdAt: Date(timeIntervalSince1970: 0),
            model: "gpt-4.1",
            status: .completed,
            output: [
                ResponseOutput(
                    id: "out_1",
                    role: .assistant,
                    content: [.outputText("final answer")]
                )
            ]
        )

        let responseDictionary = try Self.makeAnyCodableDictionary(response)
        let event = ResponseStreamEvent(
            type: "response.completed",
            data: [
                "response": AnyCodable(responseDictionary)
            ]
        )

        snapshot = ConversationStreamReducer.reduce(snapshot: snapshot, with: event)

        XCTAssertEqual(snapshot.messages.last?.text, "final answer")
        if case .completed = snapshot.responsePhase {
            // success
        } else {
            XCTFail("Expected completed phase")
        }
    }

    func testWebSearchEventsUpdatePhase() {
        var snapshot = ConversationStateSnapshot()

        let created = ResponseStreamEvent(type: "response.web_search_call.created", data: [:])
        snapshot = ConversationStreamReducer.reduce(snapshot: snapshot, with: created)
        if case .initiated = snapshot.webSearchPhase {
            // ok
        } else {
            XCTFail("Expected initiated phase")
        }

        let completed = ResponseStreamEvent(type: "response.web_search_call.completed", data: [:])
        snapshot = ConversationStreamReducer.reduce(snapshot: snapshot, with: completed)
        if case .completed = snapshot.webSearchPhase {
            // ok
        } else {
            XCTFail("Expected completed phase")
        }
    }

    func testReasoningEventsUpdatePhase() {
        var snapshot = ConversationStateSnapshot()

        let created = ResponseStreamEvent(type: "response.reasoning.created", data: [:])
        snapshot = ConversationStreamReducer.reduce(snapshot: snapshot, with: created)
        if case .drafting = snapshot.reasoningPhase {
            // ok
        } else {
            XCTFail("Expected drafting phase")
        }

        let delta = ResponseStreamEvent(type: "response.reasoning_summary_text.delta", data: [:])
        snapshot = ConversationStreamReducer.reduce(snapshot: snapshot, with: delta)
        if case .reasoning = snapshot.reasoningPhase {
            // ok
        } else {
            XCTFail("Expected reasoning phase")
        }

        let completed = ResponseStreamEvent(type: "response.reasoning_summary.completed", data: ["summary": AnyCodable("All good")])
        snapshot = ConversationStreamReducer.reduce(snapshot: snapshot, with: completed)
        if case .completed(let summary) = snapshot.reasoningPhase {
            XCTAssertEqual(summary, "All good")
        } else {
            XCTFail("Expected completed phase")
        }
    }

    func testToolCallEventsUpdatePhase() {
        var snapshot = ConversationStateSnapshot()

        let created = ResponseStreamEvent(type: "response.tool_call.created", data: ["name": AnyCodable("calendar"), "type": AnyCodable("function")])
        snapshot = ConversationStreamReducer.reduce(snapshot: snapshot, with: created)
        if case .running(let name, let type) = snapshot.toolCallPhase {
            XCTAssertEqual(name, "calendar")
            XCTAssertEqual(type, "function")
        } else {
            XCTFail("Expected running phase")
        }

        let completed = ResponseStreamEvent(type: "response.tool_call.completed", data: ["name": AnyCodable("calendar"), "type": AnyCodable("function")])
        snapshot = ConversationStreamReducer.reduce(snapshot: snapshot, with: completed)
        if case .completed(let name, _) = snapshot.toolCallPhase {
            XCTAssertEqual(name, "calendar")
        } else {
            XCTFail("Expected completed phase")
        }
    }

    private static func makeAnyCodableDictionary<T: Encodable>(_ value: T) throws -> [String: AnyCodable] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = json as? [String: Any] else {
            return [:]
        }
        return dictionary.mapValues(AnyCodable.init)
    }

    private static func makeEventData(_ value: [String: Any]) -> [String: AnyCodable] {
        value.mapValues(AnyCodable.init)
    }
}
