import Foundation

// MARK: - Generic Value Containers

public struct AnyCodable: Codable, @unchecked Sendable, Equatable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported value in AnyCodable")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var unwrapped: Any = value
        while let wrapped = unwrapped as? AnyCodable {
            unwrapped = wrapped.value
        }
        switch unwrapped {
        case _ as NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(unwrapped, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported value in AnyCodable"))
        }
    }

    public var stringValue: String? {
        value as? String
    }

    public var boolValue: Bool? {
        value as? Bool
    }

    public var intValue: Int? {
        switch value {
        case let int as Int:
            return int
        case let double as Double:
            return Int(double)
        default:
            return nil
        }
    }

    public var doubleValue: Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        default:
            return nil
        }
    }

    public var dictionaryValue: [String: AnyCodable]? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }
        var result: [String: AnyCodable] = [:]
        for (key, value) in dictionary {
            result[key] = AnyCodable(value)
        }
        return result
    }

    public var arrayValue: [AnyCodable]? {
        guard let array = value as? [Any] else {
            return nil
        }
        return array.map { AnyCodable($0) }
    }

    fileprivate var jsonObject: Any {
        var unwrapped: Any = value
        while let wrapped = unwrapped as? AnyCodable {
            unwrapped = wrapped.value
        }
        if let dictionary = unwrapped as? [String: Any] {
            var converted: [String: Any] = [:]
            for (key, value) in dictionary {
                converted[key] = AnyCodable(value).jsonObject
            }
            return converted
        }
        if let array = unwrapped as? [Any] {
            return array.map { AnyCodable($0).jsonObject }
        }
        return unwrapped
    }
}

public func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
    switch (lhs.value, rhs.value) {
    case (_ as NSNull, _ as NSNull):
        return true
    case let (l as Bool, r as Bool):
        return l == r
    case let (l as Int, r as Int):
        return l == r
    case let (l as Double, r as Double):
        return l == r
    case let (l as String, r as String):
        return l == r
    case let (l as [String: Any], r as [String: Any]):
        return NSDictionary(dictionary: l).isEqual(to: r)
    case let (l as [Any], r as [Any]):
        return NSArray(array: l).isEqual(to: r)
    default:
        return false
    }
}

extension Dictionary where Key == String, Value == AnyCodable {
    fileprivate func jsonObject() -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in self {
            result[key] = value.jsonObject
        }
        return result
    }

    fileprivate func decode<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject()) else {
            return nil
        }
        return try? decoder.decode(T.self, from: data)
    }
}

extension Array where Element == AnyCodable {
    fileprivate func jsonObject() -> [Any] {
        map { $0.jsonObject }
    }
}

// MARK: - JSON Schema

public struct JSONSchema: Codable, Sendable, Equatable {
    public var value: [String: AnyCodable]

    public init(value: [String: AnyCodable] = [:]) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode([String: AnyCodable].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Status & Usage Metadata

public enum ResponseStatus: String, Codable, Sendable {
    case queued
    case inProgress = "in_progress"
    case completed
    case incomplete
    case failed
    case cancelled
}

public struct ResponseStatusDetails: Codable, Sendable, Equatable {
    public var type: String?
    public var reason: String?
    public var raw: [String: AnyCodable]

    public init(type: String? = nil, reason: String? = nil, raw: [String: AnyCodable] = [:]) {
        self.type = type
        self.reason = reason
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: AnyCodable].self)
        self.type = raw["type"]?.stringValue
        self.reason = raw["reason"]?.stringValue
        self.raw = raw
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

public struct ResponseIncompleteDetails: Codable, Sendable, Equatable {
    public var reason: String?
    public var type: String?
    public var raw: [String: AnyCodable]

    public init(reason: String? = nil, type: String? = nil, raw: [String: AnyCodable] = [:]) {
        self.reason = reason
        self.type = type
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: AnyCodable].self)
        self.reason = raw["reason"]?.stringValue
        self.type = raw["type"]?.stringValue
        self.raw = raw
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

public struct ResponseRefusal: Codable, Sendable, Equatable {
    public var reason: String?
    public var message: String?
    public var raw: [String: AnyCodable]

    public init(reason: String? = nil, message: String? = nil, raw: [String: AnyCodable] = [:]) {
        self.reason = reason
        self.message = message
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: AnyCodable].self)
        self.reason = raw["reason"]?.stringValue
        self.message = raw["message"]?.stringValue
        self.raw = raw
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

public struct ResponseError: Codable, Sendable, Equatable {
    public var code: String?
    public var message: String?
    public var param: String?
    public var raw: [String: AnyCodable]

    public init(code: String? = nil, message: String? = nil, param: String? = nil, raw: [String: AnyCodable] = [:]) {
        self.code = code
        self.message = message
        self.param = param
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: AnyCodable].self)
        self.code = raw["code"]?.stringValue
        self.message = raw["message"]?.stringValue
        self.param = raw["param"]?.stringValue
        self.raw = raw
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

public struct ResponseUsage: Codable, Sendable, Equatable {
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var totalTokens: Int?
    public var reasoningTokens: Int?
    public var audioTokens: Int?
    public var cacheCreationTokens: Int?
    public var cacheReadTokens: Int?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil,
        reasoningTokens: Int? = nil,
        audioTokens: Int? = nil,
        cacheCreationTokens: Int? = nil,
        cacheReadTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.reasoningTokens = reasoningTokens
        self.audioTokens = audioTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
        case reasoningTokens = "reasoning_tokens"
        case audioTokens = "audio_tokens"
        case cacheCreationTokens = "cache_creation_tokens"
        case cacheReadTokens = "cache_read_tokens"
    }
}

// MARK: - Response Options

public enum ResponseModality: String, Codable, Sendable {
    case text
    case audio
    case image
    case video
}

public struct ResponseFormat: Codable, Sendable, Equatable {
    public enum FormatType: String, Codable, Sendable {
        case auto
        case text
        case jsonSchema = "json_schema"
    }

    public var type: FormatType
    public var jsonSchema: JSONSchema?
    public var strict: Bool?

    public init(type: FormatType = .auto, jsonSchema: JSONSchema? = nil, strict: Bool? = nil) {
        self.type = type
        self.jsonSchema = jsonSchema
        self.strict = strict
    }

    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
        case strict
    }
}

public struct ResponseAudioOptions: Codable, Sendable, Equatable {
    public var voice: String?
    public var format: String?

    public init(voice: String? = nil, format: String? = nil) {
        self.voice = voice
        self.format = format
    }
}

public struct ResponseReasoningOptions: Codable, Sendable, Equatable {
    public var effort: String?
    public var minOutputTokens: Int?
    public var maxOutputTokens: Int?

    public init(effort: String? = nil, minOutputTokens: Int? = nil, maxOutputTokens: Int? = nil) {
        self.effort = effort
        self.minOutputTokens = minOutputTokens
        self.maxOutputTokens = maxOutputTokens
    }

    enum CodingKeys: String, CodingKey {
        case effort
        case minOutputTokens = "min_output_tokens"
        case maxOutputTokens = "max_output_tokens"
    }
}

public struct ResponseTruncationStrategy: Codable, Sendable, Equatable {
    public var type: String?
    public var maxInputTokens: Int?

    public init(type: String? = nil, maxInputTokens: Int? = nil) {
        self.type = type
        self.maxInputTokens = maxInputTokens
    }

    enum CodingKeys: String, CodingKey {
        case type
        case maxInputTokens = "max_input_tokens"
    }
}

// MARK: - Tool Definitions

public struct ResponseToolDefinition: Codable, Sendable, Equatable {
    public var type: String
    public var name: String
    public var description: String?
    public var inputSchema: JSONSchema

    public init(type: String = "function", name: String, description: String? = nil, inputSchema: JSONSchema) {
        self.type = type
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }

    enum CodingKeys: String, CodingKey {
        case type
        case name
        case description
        case inputSchema = "parameters"
    }
}

public enum ToolChoice: Codable, Sendable, Equatable {
    case none
    case auto
    case required
    case named(String)
    case other(type: String, payload: [String: AnyCodable])

    enum CodingKeys: String, CodingKey {
        case type
        case function
    }

    private struct FunctionPayload: Codable, Sendable, Equatable {
        var name: String
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dictionary = try container.decode([String: AnyCodable].self)
        let type = dictionary["type"]?.stringValue ?? "auto"
        switch type {
        case "none":
            self = .none
        case "auto":
            self = .auto
        case "required":
            self = .required
        case "function", "tool":
            let name = dictionary["function"]?.dictionaryValue? ["name"]?.stringValue
                ?? dictionary["name"]?.stringValue
                ?? ""
            self = .named(name)
        default:
            self = .other(type: type, payload: dictionary)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode(["type": AnyCodable("none")])
        case .auto:
            try container.encode(["type": AnyCodable("auto")])
        case .required:
            try container.encode(["type": AnyCodable("required")])
        case .named(let name):
            let payload: [String: AnyCodable] = [
                "type": AnyCodable("function"),
                "function": AnyCodable(["name": name])
            ]
            try container.encode(payload)
        case .other(_, let payload):
            try container.encode(payload)
        }
    }
}

public struct ResponseToolCall: Codable, Sendable, Equatable, Identifiable {
    public struct Arguments: Codable, Sendable, Equatable {
        public var string: String?
        public var json: [String: AnyCodable]?

        public init(string: String? = nil, json: [String: AnyCodable]? = nil) {
            self.string = string
            self.json = json
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self.string = string
                if let data = string.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.json = jsonObject.mapValues { AnyCodable($0) }
                } else {
                    self.json = nil
                }
            } else if let dictionary = try? container.decode([String: AnyCodable].self) {
                self.json = dictionary
                self.string = nil
            } else {
                self.string = nil
                self.json = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            if let string {
                try container.encode(string)
            } else if let json {
                try container.encode(json)
            } else {
                try container.encodeNil()
            }
        }
    }

    public var type: String
    public var id: String
    public var name: String
    public var arguments: Arguments

    public init(type: String = "tool_call", id: String, name: String, arguments: Arguments) {
        self.type = type
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

public struct ResponseToolOutput: Codable, Sendable, Equatable {
    public var type: String
    public var toolCallId: String
    public var output: AnyCodable

    public init(type: String = "tool_output", toolCallId: String, output: AnyCodable) {
        self.type = type
        self.toolCallId = toolCallId
        self.output = output
    }

    enum CodingKeys: String, CodingKey {
        case type
        case toolCallId = "tool_call_id"
        case output
    }
}

// MARK: - Content Blocks

public struct ResponseContentBlock: Codable, Sendable, Equatable {
    public var type: String
    public var data: [String: AnyCodable]

    public init(type: String, data: [String: AnyCodable] = [:]) {
        var payload = data
        payload["type"] = AnyCodable(type)
        self.type = type
        self.data = payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dictionary = try container.decode([String: AnyCodable].self)
        self.type = dictionary["type"]?.stringValue ?? "unknown"
        self.data = dictionary
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }

    public var text: String? {
        data["text"]?.stringValue
    }

    public var annotations: [AnyCodable]? {
        data["annotations"]?.arrayValue
    }

    public var toolCall: ResponseToolCall? {
        guard type == "tool_call" else {
            return nil
        }
        return data.decode(ResponseToolCall.self)
    }

    public var toolOutput: ResponseToolOutput? {
        guard type == "tool_output" else {
            return nil
        }
        return data.decode(ResponseToolOutput.self)
    }

    public func decode<T: Decodable>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) -> T? {
        data.decode(type, using: decoder)
    }
}

public extension ResponseContentBlock {
    static func text(_ value: String) -> ResponseContentBlock {
        ResponseContentBlock(type: "text", data: ["text": AnyCodable(value)])
    }

    static func inputText(_ value: String) -> ResponseContentBlock {
        ResponseContentBlock(type: "input_text", data: ["text": AnyCodable(value)])
    }

    static func outputText(_ value: String) -> ResponseContentBlock {
        ResponseContentBlock(type: "output_text", data: ["text": AnyCodable(value)])
    }

    static func imageURL(_ url: URL) -> ResponseContentBlock {
        ResponseContentBlock(type: "image_url", data: ["image_url": AnyCodable(["url": url.absoluteString])])
    }

    static func json(_ object: [String: Any]) -> ResponseContentBlock {
        ResponseContentBlock(type: "json", data: ["json": AnyCodable(object)])
    }
}

public enum MessageRole: String, Codable, Sendable {
    case user
    case system
    case assistant
    case tool
    case developer
}

public struct ResponseMessageInput: Codable, Sendable, Equatable {
    public var role: MessageRole
    public var content: [ResponseContentBlock]
    public var metadata: [String: AnyCodable]?

    public init(role: MessageRole, content: [ResponseContentBlock], metadata: [String: AnyCodable]? = nil) {
        self.role = role
        self.content = content
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case metadata
    }
}

public enum ResponseInputItem: Codable, Sendable, Equatable {
    case message(ResponseMessageInput)
    case raw([String: AnyCodable])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dictionary = try container.decode([String: AnyCodable].self)
        if let roleValue = dictionary["role"]?.stringValue,
           let role = MessageRole(rawValue: roleValue),
           let contentValues = dictionary["content"]?.arrayValue {
            let blocks: [ResponseContentBlock] = contentValues.compactMap { value in
                guard let payload = value.dictionaryValue else { return nil }
                return ResponseContentBlock(type: payload["type"]?.stringValue ?? "unknown", data: payload)
            }
            let metadata = dictionary["metadata"]?.dictionaryValue
            self = .message(ResponseMessageInput(role: role, content: blocks, metadata: metadata))
        } else {
            self = .raw(dictionary)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .message(let message):
            let contentPayload: [Any] = message.content.map { $0.data.jsonObject() }
            var payload: [String: AnyCodable] = [
                "role": AnyCodable(message.role.rawValue),
                "content": AnyCodable(contentPayload)
            ]
            if let metadata = message.metadata {
                payload["metadata"] = AnyCodable(metadata.jsonObject())
            }
            try container.encode(payload)
        case .raw(let dictionary):
            try container.encode(dictionary)
        }
    }
}

public extension ResponseInputItem {
    static func message(role: MessageRole, content: [ResponseContentBlock], metadata: [String: AnyCodable]? = nil) -> ResponseInputItem {
        .message(ResponseMessageInput(role: role, content: content, metadata: metadata))
    }
}

// MARK: - Outputs & Responses

public struct ResponseOutput: Codable, Sendable, Equatable {
    public var id: String
    public var role: MessageRole
    public var content: [ResponseContentBlock]
    public var status: String?
    public var metadata: [String: AnyCodable]?
    public var finishReason: String?
    public var refusal: ResponseRefusal?

    public init(
        id: String,
        role: MessageRole,
        content: [ResponseContentBlock],
        status: String? = nil,
        metadata: [String: AnyCodable]? = nil,
        finishReason: String? = nil,
        refusal: ResponseRefusal? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.status = status
        self.metadata = metadata
        self.finishReason = finishReason
        self.refusal = refusal
    }

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case status
        case metadata
        case finishReason = "finish_reason"
        case refusal
    }
}

public struct ResponseObject: Codable, Sendable, Equatable {
    public var id: String
    public var object: String
    public var createdAt: Date
    public var model: String
    public var status: ResponseStatus
    public var statusDetails: ResponseStatusDetails?
    public var incompleteDetails: ResponseIncompleteDetails?
    public var usage: ResponseUsage?
    public var modalities: [ResponseModality]?
    public var responseFormat: ResponseFormat?
    public var instructions: String?
    public var output: [ResponseOutput]
    public var metadata: [String: AnyCodable]?
    public var temperature: Double?
    public var topP: Double?
    public var conversationId: String?
    public var session: String?
    public var finishReason: String?
    public var refusal: ResponseRefusal?
    public var error: ResponseError?

    public init(
        id: String,
        object: String = "response",
        createdAt: Date,
        model: String,
        status: ResponseStatus,
        statusDetails: ResponseStatusDetails? = nil,
        incompleteDetails: ResponseIncompleteDetails? = nil,
        usage: ResponseUsage? = nil,
        modalities: [ResponseModality]? = nil,
        responseFormat: ResponseFormat? = nil,
        instructions: String? = nil,
        output: [ResponseOutput] = [],
        metadata: [String: AnyCodable]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        conversationId: String? = nil,
        session: String? = nil,
        finishReason: String? = nil,
        refusal: ResponseRefusal? = nil,
        error: ResponseError? = nil
    ) {
        self.id = id
        self.object = object
        self.createdAt = createdAt
        self.model = model
        self.status = status
        self.statusDetails = statusDetails
        self.incompleteDetails = incompleteDetails
        self.usage = usage
        self.modalities = modalities
        self.responseFormat = responseFormat
        self.instructions = instructions
        self.output = output
        self.metadata = metadata
        self.temperature = temperature
        self.topP = topP
        self.conversationId = conversationId
        self.session = session
        self.finishReason = finishReason
        self.refusal = refusal
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case createdAt = "created_at"
        case model
        case status
        case statusDetails = "status_details"
        case incompleteDetails = "incomplete_details"
        case usage
        case modalities
        case responseFormat = "response_format"
        case instructions
        case output
        case metadata
        case temperature
        case topP = "top_p"
        case conversationId = "conversation_id"
        case session
        case finishReason = "finish_reason"
        case refusal
        case error
    }
}

public struct ResponseList: Codable, Sendable, Equatable {
    public var object: String
    public var data: [ResponseObject]
    public var hasMore: Bool
    public var firstId: String?
    public var lastId: String?
    public var nextPageToken: String?

    public init(
        object: String = "list",
        data: [ResponseObject],
        hasMore: Bool,
        firstId: String? = nil,
        lastId: String? = nil,
        nextPageToken: String? = nil
    ) {
        self.object = object
        self.data = data
        self.hasMore = hasMore
        self.firstId = firstId
        self.lastId = lastId
        self.nextPageToken = nextPageToken
    }

    enum CodingKeys: String, CodingKey {
        case object
        case data
        case hasMore = "has_more"
        case firstId = "first_id"
        case lastId = "last_id"
        case nextPageToken = "next_page_token"
    }
}

// MARK: - Request Payload

public struct ResponseCreateRequest: Codable, Sendable, Equatable {
    public var model: String
    public var input: [ResponseInputItem]
    public var instructions: String?
    public var modalities: [ResponseModality]?
    public var responseFormat: ResponseFormat?
    public var audio: ResponseAudioOptions?
    public var metadata: [String: AnyCodable]?
    public var temperature: Double?
    public var topP: Double?
    public var frequencyPenalty: Double?
    public var presencePenalty: Double?
    public var stop: [String]?
    public var maxOutputTokens: Int?
    public var maxInputTokens: Int?
    public var truncationStrategy: ResponseTruncationStrategy?
    public var reasoning: ResponseReasoningOptions?
    public var logitBias: [String: Double]?
    public var seed: Int?
    public var parallelToolCalls: Bool?
    public var tools: [ResponseToolDefinition]?
    public var toolChoice: ToolChoice?
    public var session: String?
    public var previousResponseId: String?

    public init(
        model: String,
        input: [ResponseInputItem],
        instructions: String? = nil,
        modalities: [ResponseModality]? = nil,
        responseFormat: ResponseFormat? = nil,
        audio: ResponseAudioOptions? = nil,
        metadata: [String: AnyCodable]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stop: [String]? = nil,
        maxOutputTokens: Int? = nil,
        maxInputTokens: Int? = nil,
        truncationStrategy: ResponseTruncationStrategy? = nil,
        reasoning: ResponseReasoningOptions? = nil,
        logitBias: [String: Double]? = nil,
        seed: Int? = nil,
        parallelToolCalls: Bool? = nil,
        tools: [ResponseToolDefinition]? = nil,
        toolChoice: ToolChoice? = nil,
        session: String? = nil,
        previousResponseId: String? = nil
    ) {
        self.model = model
        self.input = input
        self.instructions = instructions
        self.modalities = modalities
        self.responseFormat = responseFormat
        self.audio = audio
        self.metadata = metadata
        self.temperature = temperature
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stop = stop
        self.maxOutputTokens = maxOutputTokens
        self.maxInputTokens = maxInputTokens
        self.truncationStrategy = truncationStrategy
        self.reasoning = reasoning
        self.logitBias = logitBias
        self.seed = seed
        self.parallelToolCalls = parallelToolCalls
        self.tools = tools
        self.toolChoice = toolChoice
        self.session = session
        self.previousResponseId = previousResponseId
    }

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case instructions
        case modalities
        case responseFormat = "response_format"
        case audio
        case metadata
        case temperature
        case topP = "top_p"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
        case stop
        case maxOutputTokens = "max_output_tokens"
        case maxInputTokens = "max_input_tokens"
        case truncationStrategy = "truncate"
        case reasoning
        case logitBias = "logit_bias"
        case seed
        case parallelToolCalls = "parallel_tool_calls"
        case tools
        case toolChoice = "tool_choice"
        case session
        case previousResponseId = "previous_response_id"
    }
}

// MARK: - Streaming Events

public struct ResponseDelta: Sendable, Equatable {
    public let type: String?
    public let data: [String: AnyCodable]

    public init(type: String?, data: [String: AnyCodable]) {
        self.type = type
        self.data = data
    }

    public var text: String? {
        data["text"]?.stringValue ?? data["output_text"]?.stringValue
    }

    public var toolCalls: [ResponseToolCall]? {
        guard let values = data["tool_calls"]?.arrayValue else {
            return nil
        }
        return values.compactMap { $0.dictionaryValue?.decode(ResponseToolCall.self) }
    }
}

public struct ResponseStreamEvent: Sendable, Equatable {
    public let type: String
    public let data: [String: AnyCodable]

    public init(type: String, data: [String: AnyCodable]) {
        self.type = type
        self.data = data
    }

    public var status: ResponseStatus? {
        guard let value = data["status"]?.stringValue else { return nil }
        return ResponseStatus(rawValue: value)
    }

    public var responseId: String? {
        data["response_id"]?.stringValue ?? data["id"]?.stringValue
    }

    public var delta: ResponseDelta? {
        guard let payload = data["delta"]?.dictionaryValue else { return nil }
        return ResponseDelta(type: payload["type"]?.stringValue, data: payload)
    }

    public var error: ResponseError? {
        guard let payload = data["error"]?.dictionaryValue else { return nil }
        return payload.decode(ResponseError.self)
    }

    public var response: ResponseObject? {
        guard let payload = data["response"]?.dictionaryValue else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return payload.decode(ResponseObject.self, using: decoder)
    }
}
