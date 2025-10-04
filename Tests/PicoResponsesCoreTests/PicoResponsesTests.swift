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
                    .inputText("Hello")
                ]
            )
        ],
        instructions: "Be concise",
        modalities: [.text],
        responseFormat: ResponseFormat(type: .jsonSchema, jsonSchema: JSONSchema(value: [
            "type": AnyCodable("object")
        ]), strict: true),
        audio: ResponseAudioOptions(voice: "alloy", format: "wav"),
        metadata: ["conversation_id": AnyCodable("conv_123"), "attempt": AnyCodable(1)],
        temperature: 0.3,
        topP: 0.9,
        frequencyPenalty: 0.1,
        presencePenalty: 0.2,
        stop: ["END"],
        maxOutputTokens: 256,
        maxInputTokens: 2048,
        truncationStrategy: ResponseTruncationStrategy(type: "auto", maxInputTokens: 2048),
        reasoning: ResponseReasoningOptions(effort: "medium", minOutputTokens: 8, maxOutputTokens: 128),
        logitBias: ["42": -2.5],
        seed: 123,
        parallelToolCalls: false,
        tools: [
            ResponseToolDefinition(
                name: "weather",
                description: "Get the forecast",
                inputSchema: JSONSchema(value: [
                    "type": AnyCodable("object")
                ])
            )
        ],
        toolChoice: .auto,
        session: "sess_123",
        previousResponseId: "resp_456"
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

    #expect(first["role"] as? String == "user")
    #expect(firstContent["type"] as? String == "input_text")
    #expect(firstContent["text"] as? String == "Hello")

    #expect(json? ["instructions"] as? String == "Be concise")
    let responseFormat = json? ["response_format"] as? [String: Any]
    #expect(responseFormat? ["type"] as? String == "json_schema")
    let responseSchema = responseFormat? ["json_schema"] as? [String: Any]
    #expect(responseSchema? ["type"] as? String == "object")
    #expect(responseFormat? ["strict"] as? Bool == true)
    #expect(json? ["parallel_tool_calls"] as? Bool == false)
    #expect(json? ["seed"] as? Int == 123)
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

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let parser = ResponseStreamParser(decoder: decoder)
    var results: [ResponseStreamEvent] = []
    for try await event in parser.parse(stream: stream) {
        results.append(event)
    }

    #expect(results.count == 3)
    guard results.count == 3 else { return }

    #expect(results[0].type == "response.output_text.delta")
    #expect(results[0].status == .inProgress)
    let firstItem = results[0].data["item"]?.dictionaryValue
    let firstContent = firstItem? ["content"]?.arrayValue?.first?.dictionaryValue
    #expect(firstContent? ["text"]?.stringValue == "Hel")

    #expect(results[1].type == "response.output_text.delta")
    let secondItem = results[1].data["item"]?.dictionaryValue
    let secondContent = secondItem? ["content"]?.arrayValue?.first?.dictionaryValue
    #expect(secondContent? ["text"]?.stringValue == "lo")

    #expect(results[2].type == "done")
}
