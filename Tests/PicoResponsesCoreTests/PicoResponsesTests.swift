import EventSource
import Foundation
import Testing
@testable import PicoResponsesCore

private func parseEvents(_ frames: [String]) async -> [EventSource.Event] {
    let parser = EventSource.Parser()
    for frame in frames {
        for byte in frame.utf8 {
            await parser.consume(byte)
        }
    }
    await parser.finish()
    var events: [EventSource.Event] = []
    while let event = await parser.getNextEvent() {
        events.append(event)
    }
    return events
}

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
        responseFormat: ResponseFormat(
            type: .jsonSchema,
            jsonSchema: .object(
                properties: [
                    "summary": .string(minLength: 1, maxLength: 256, description: "Short blurb"),
                    "score": .number(minimum: 0, maximum: 1)
                ],
                required: ["summary"],
                additionalProperties: .boolean(false)
            ),
            strict: true
        ),
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
                inputSchema: .object(
                    properties: [
                        "location": .string(minLength: 1, description: "City name"),
                        "unit": .enumeration([
                            AnyCodable("celsius"),
                            AnyCodable("fahrenheit")
                        ])
                    ],
                    required: ["location"],
                    additionalProperties: .boolean(false)
                )
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
    let responseProperties = responseSchema? ["properties"] as? [String: Any]
    let summarySchema = responseProperties? ["summary"] as? [String: Any]
    #expect(summarySchema? ["type"] as? String == "string")
    #expect(summarySchema? ["minLength"] as? Int == 1)
    #expect(summarySchema? ["maxLength"] as? Int == 256)
    let scoreSchema = responseProperties? ["score"] as? [String: Any]
    #expect(scoreSchema? ["type"] as? String == "number")
    #expect(scoreSchema? ["minimum"] as? Double == 0)
    #expect(scoreSchema? ["maximum"] as? Double == 1)
    let requiredFields = responseSchema? ["required"] as? [String]
    #expect(requiredFields?.contains("summary") == true)
    #expect(responseSchema? ["additionalProperties"] as? Bool == false)
    let tools = json? ["tools"] as? [[String: Any]]
    let firstTool = tools?.first
    let inputSchema = firstTool? ["parameters"] as? [String: Any]
    #expect(inputSchema? ["type"] as? String == "object")
    let toolProperties = inputSchema? ["properties"] as? [String: Any]
    let locationSchema = toolProperties? ["location"] as? [String: Any]
    #expect(locationSchema? ["minLength"] as? Int == 1)
    let unitSchema = toolProperties? ["unit"] as? [String: Any]
    let unitEnum = unitSchema? ["enum"] as? [String]
    #expect(unitEnum?.contains("celsius") == true)
    #expect(json? ["parallel_tool_calls"] as? Bool == false)
    #expect(json? ["seed"] as? Int == 123)
}

@Test func responseObjectDecodesAdditionalTimestamps() throws {
    let json = """
    {
        "id": "resp_123",
        "object": "response",
        "created_at": 1,
        "completed_at": 2,
        "updated_at": 3,
        "expires_at": 4,
        "model": "gpt-4o-mini",
        "status": "completed",
        "output": []
    }
    """

    let data = Data(json.utf8)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let response = try decoder.decode(ResponseObject.self, from: data)

    #expect(response.createdAt == Date(timeIntervalSince1970: 1))
    #expect(response.completedAt == Date(timeIntervalSince1970: 2))
    #expect(response.updatedAt == Date(timeIntervalSince1970: 3))
    #expect(response.expiresAt == Date(timeIntervalSince1970: 4))
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

@Test func responseToolDefinitionEncodesMCPMetadata() throws {
    let definition = ResponseToolDefinition(
        name: "calendar",
        description: "Calendar availability",
        inputSchema: .object(properties: [:]),
        mcpServer: ResponseToolDefinition.MCPServer(
            label: "Primary Calendar",
            url: URL(string: "https://mcp.example.com")!,
            transport: "sse",
            version: "2024-09-01",
            auth: ["type": AnyCodable("bearer"), "scopes": AnyCodable(["calendar.read"])],
            options: ["region": AnyCodable("us-west-2")],
            metadata: ["environment": AnyCodable("prod")]
        )
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(definition)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    let server = json? ["server"] as? [String: Any]
    #expect(server? ["label"] as? String == "Primary Calendar")
    #expect(server? ["url"] as? String == "https://mcp.example.com")
    #expect(server? ["transport"] as? String == "sse")
    #expect(server? ["version"] as? String == "2024-09-01")
    let auth = json? ["server_auth"] as? [String: Any]
    #expect(auth? ["type"] as? String == "bearer")
    let scopes = auth? ["scopes"] as? [String]
    #expect(scopes?.contains("calendar.read") == true)
    let options = json? ["server_options"] as? [String: Any]
    #expect(options? ["region"] as? String == "us-west-2")
    #expect(json? ["server_label"] as? String == "Primary Calendar")
    #expect(json? ["server_url"] as? String == "https://mcp.example.com")
    let metadata = json? ["server_metadata"] as? [String: Any]
    #expect(metadata? ["environment"] as? String == "prod")
}

@Test func responseToolCallDecodesMCPDetails() throws {
    let payload: [String: Any] = [
        "type": "tool_call",
        "id": "call_123",
        "name": "find_calendar_slot",
        "arguments": ["date": "2024-12-01", "participants": ["alice", "bob"]],
        "status": "completed",
        "started_at": 100.5,
        "completed_at": 102.75,
        "metadata": ["attempt": 2],
        "execution_context": ["span_id": "span_456"],
        "file_ids": ["file_A"],
        "error": ["code": "warning", "message": "Minor delay"]
    ]

    let data = try JSONSerialization.data(withJSONObject: payload)
    let decoder = JSONDecoder()
    let call = try decoder.decode(ResponseToolCall.self, from: data)

    #expect(call.id == "call_123")
    #expect(call.name == "find_calendar_slot")
    #expect(call.arguments.dictionaryValue? ["date"]?.stringValue == "2024-12-01")
    let participants = call.arguments.dictionaryValue? ["participants"]?.arrayValue?.compactMap { $0.stringValue }
    #expect(participants == ["alice", "bob"])
    #expect(call.status == "completed")
    #expect(call.startedAt == Date(timeIntervalSince1970: 100.5))
    #expect(call.completedAt == Date(timeIntervalSince1970: 102.75))
    #expect(call.metadata? ["attempt"]?.intValue == 2)
    #expect(call.executionContext? ["span_id"]?.stringValue == "span_456")
    #expect(call.fileIds == ["file_A"])
    #expect(call.error?.code == "warning")

    let encoded = try JSONEncoder().encode(call)
    let encodedJSON = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    #expect(encodedJSON? ["started_at"] as? Double == 100.5)
    #expect((encodedJSON? ["metadata"] as? [String: Any])? ["attempt"] as? Int == 2)
}

@Test func responseToolOutputHandlesStructuredPayloads() throws {
    let jsonPayload: [String: Any] = [
        "type": "tool_output",
        "tool_call_id": "call_123",
        "output": ["status": "ok", "count": 2],
        "content_type": "application/json",
        "metadata": ["duration_ms": 120]
    ]

    let data = try JSONSerialization.data(withJSONObject: jsonPayload)
    let decoder = JSONDecoder()
    let output = try decoder.decode(ResponseToolOutput.self, from: data)

    #expect(output.toolCallId == "call_123")
    #expect(output.contentType == "application/json")
    #expect(output.jsonValue? ["status"]?.stringValue == "ok")
    #expect(output.jsonValue? ["count"]?.intValue == 2)
    #expect(output.metadata? ["duration_ms"]?.intValue == 120)

    let textOutput = ResponseToolOutput(
        toolCallId: "call_text",
        payload: .string("{\"summary\":\"done\"}")
    )
    let encoded = try JSONEncoder().encode(textOutput)
    let encodedJSON = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    #expect(encodedJSON? ["output"] as? String == "{\"summary\":\"done\"}")
    let decodedText = try decoder.decode(ResponseToolOutput.self, from: encoded)
    #expect(decodedText.stringValue == "{\"summary\":\"done\"}")
}

@Test func responseStreamParserParsesChunks() async throws {
    let frames = [
        "data: {\"type\":\"response.output_text.delta\",\"status\":\"in_progress\",\"item\":{\"id\":\"item_1\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"Hel\"}]}}\n\n",
        "data: {\"type\":\"response.output_text.delta\",\"item\":{\"id\":\"item_1\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"lo\"}]}}\n\n",
        "data: [DONE]\n\n"
    ]

    let events = await parseEvents(frames)

    let stream = AsyncThrowingStream<EventSource.Event, Error> { continuation in
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

@Test func jsonSchemaEncodingAndDecoding() throws {
    let schema = JSONSchema.object(
        properties: [
            "name": .string(minLength: 1, maxLength: 64, description: "Display name"),
            "age": .integer(minimum: 0, maximum: 150),
            "tags": .array(items: .string(), minItems: 1)
        ],
        patternProperties: ["^x-": .string()],
        required: ["name", "age"],
        additionalProperties: .schema(.string()),
        description: "Person record"
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(schema)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json? ["type"] as? String == "object")
    let required = json? ["required"] as? [String]
    #expect(required == ["age", "name"] || required == ["name", "age"])
    let additional = json? ["additionalProperties"] as? [String: Any]
    #expect(additional? ["type"] as? String == "string")
    let pattern = json? ["patternProperties"] as? [String: Any]
    let customHeader = pattern? ["^x-"] as? [String: Any]
    #expect(customHeader? ["type"] as? String == "string")

    let decoded = try JSONDecoder().decode(JSONSchema.self, from: data)
    #expect(decoded == schema)

    let document = JSONSchema.document(
        root: schema,
        definitions: [
            "Location": .object(
                properties: [
                    "lat": .number(),
                    "lon": .number()
                ],
                additionalProperties: .boolean(false)
            )
        ]
    )
    let documentData = try encoder.encode(document)
    let documentJSON = try JSONSerialization.jsonObject(with: documentData) as? [String: Any]
    let defs = documentJSON? ["$defs"] as? [String: Any]
    let locationSchema = defs? ["Location"] as? [String: Any]
    #expect(locationSchema? ["type"] as? String == "object")
    let decodedDocument = try JSONDecoder().decode(JSONSchema.self, from: documentData)
    if case .document(let root, let definitions) = decodedDocument {
        #expect(root == schema)
        #expect(definitions.keys.contains("Location"))
    } else {
        Issue.record("Expected document schema with $defs")
    }

    let notSchema = JSONSchema.not(.string(), description: "no strings")
    let notData = try encoder.encode(notSchema)
    let notJSON = try JSONSerialization.jsonObject(with: notData) as? [String: Any]
    #expect(notJSON? ["not"] as? [String: Any] != nil)
    let decodedNot = try JSONDecoder().decode(JSONSchema.self, from: notData)
    #expect(decodedNot == notSchema)

    let conditional = JSONSchema.conditional(
        if: .object(properties: ["kind": .constant(AnyCodable("cat"))]),
        then: .object(properties: ["purrs": .boolean()]),
        else: .object(properties: ["barks": .boolean()]),
        description: "Animal behaviour"
    )
    let conditionalData = try encoder.encode(conditional)
    let conditionalJSON = try JSONSerialization.jsonObject(with: conditionalData) as? [String: Any]
    #expect(conditionalJSON? ["if"] as? [String: Any] != nil)
    let decodedConditional = try JSONDecoder().decode(JSONSchema.self, from: conditionalData)
    #expect(decodedConditional == conditional)

    let tupleSchema = JSONSchema.tuple(
        prefixItems: [.string(), .number()],
        items: .string(),
        minItems: 2,
        maxItems: 4,
        description: "Tuple schema"
    )
    let tupleData = try encoder.encode(tupleSchema)
    let tupleJSON = try JSONSerialization.jsonObject(with: tupleData) as? [String: Any]
    let prefixSchemas = tupleJSON? ["prefixItems"] as? [[String: Any]]
    #expect(prefixSchemas?.count == 2)
    let decodedTuple = try JSONDecoder().decode(JSONSchema.self, from: tupleData)
    if case .raw(let rawValue) = decodedTuple {
        #expect(rawValue["prefixItems"] != nil)
    } else {
        Issue.record("Expected prefixItems schemas to decode as raw until tuple parsing is implemented")
    }

    let nullableData = try JSONSerialization.data(withJSONObject: [
        "type": ["string", "null"],
        "description": "Optional string"
    ])
    let nullable = try JSONDecoder().decode(JSONSchema.self, from: nullableData)
    #expect(nullable == .union([.string, .null], description: "Optional string"))

    let anyOfData = try JSONSerialization.data(withJSONObject: [
        "anyOf": [
            ["type": "string"],
            ["type": "number"]
        ],
        "description": "String or number"
    ])
    let anyOf = try JSONDecoder().decode(JSONSchema.self, from: anyOfData)
    #expect(anyOf == .anyOf([.string(), .number()], description: "String or number"))
}
