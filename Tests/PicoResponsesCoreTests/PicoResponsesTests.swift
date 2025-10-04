import Foundation
import Testing
@testable import PicoResponsesCore

@Test func responseCreateRequestEncoding() throws {
    let request = ResponseCreateRequest(
        model: "gpt-4o-mini",
        input: [
            .message(
                role: .user,
                content: [
                    .inputText(.input("Hello"))
                ]
            )
        ],
        metadata: ["conversation_id": "conv_123"],
        toolChoice: .auto
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(json? ["model"] as? String == "gpt-4o-mini")
    let metadata = json? ["metadata"] as? [String: Any]
    #expect(metadata? ["conversation_id"] as? String == "conv_123")
    let toolChoice = json? ["tool_choice"] as? [String: Any]
    #expect(toolChoice? ["type"] as? String == "auto")

    guard
        let input = json? ["input"] as? [[String: Any]],
        let first = input.first,
        let content = first["content"] as? [[String: Any]],
        let firstContent = content.first
    else {
        Issue.record("Failed to decode request JSON structure")
        return
    }

    #expect(first["type"] as? String == "message")
    #expect(first["role"] as? String == "user")
    #expect(firstContent["type"] as? String == "input_text")
    #expect(firstContent["text"] as? String == "Hello")
}

@Test func toolChoiceEncodingRoundTrip() throws {
    let choice = ToolChoice.named("weather")
    let data = try JSONEncoder().encode(choice)
    let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(raw? ["type"] as? String == "function")
    let function = raw? ["function"] as? [String: Any]
    #expect(function? ["name"] as? String == "weather")

    let decoded = try JSONDecoder().decode(ToolChoice.self, from: data)
    if case .named(let name) = decoded {
        #expect(name == "weather")
    } else {
        Issue.record("Expected named tool choice")
    }
}

@Test func responseStreamParserParsesChunks() async throws {
    let events = [
        "data: {\"type\":\"response.output_text.delta\",\"status\":\"in_progress\",\"item\":{\"id\":\"item_1\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"Hel\"}]}}\n\n",
        "data: {\"type\":\"response.output_text.delta\",\"item\":{\"id\":\"item_1\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"lo\"}]}}\n\n",
        "data: [DONE]\n\n"
    ].map { Data($0.utf8) }

    let stream = AsyncThrowingStream<Data, Error> { continuation in
        for event in events {
            continuation.yield(event)
        }
        continuation.finish()
    }

    let parser = ResponseStreamParser(decoder: JSONDecoder())
    var results: [ResponseStreamEvent] = []
    for try await event in parser.parse(stream: stream) {
        results.append(event)
    }

    #expect(results.count == 3)
    guard results.count == 3 else { return }
    if case let .chunk(first) = results[0].kind {
        #expect(first.type == "response.output_text.delta")
        #expect(first.status == .inProgress)
        #expect(first.item?.content.first?.textValue == "Hel")
    } else {
        Issue.record("Expected first event to be chunk")
    }
    if case let .chunk(second) = results[1].kind {
        #expect(second.item?.content.first?.textValue == "lo")
    } else {
        Issue.record("Expected second event to be chunk")
    }
    if case .completed = results[2].kind {
        // success
    } else {
        Issue.record("Expected final event to be completion")
    }
}

private extension ResponseContent {
    var textValue: String? {
        switch self {
        case .text(let content), .inputText(let content), .outputText(let content):
            return content.text
        default:
            return nil
        }
    }
}
