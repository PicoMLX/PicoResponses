import Foundation

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
        switch value {
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
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported value in AnyCodable"))
        }
    }
}

public func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
    switch (lhs.value, rhs.value) {
    case (_ as NSNull, _ as NSNull): return true
    case let (l as Bool, r as Bool): return l == r
    case let (l as Int, r as Int): return l == r
    case let (l as Double, r as Double): return l == r
    case let (l as String, r as String): return l == r
    case let (l as [String: Any], r as [String: Any]):
        return NSDictionary(dictionary: l).isEqual(to: r)
    case let (l as [Any], r as [Any]):
        return NSArray(array: l).isEqual(to: r)
    default:
        return false
    }
}

public enum ResponseStatus: String, Codable, Sendable {
    case queued
    case inProgress = "in_progress"
    case completed
    case incomplete
    case failed
    case cancelled
}

public struct ResponseUsage: Codable, Sendable, Equatable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var totalTokens: Int

    public init(inputTokens: Int, outputTokens: Int, totalTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
}

public struct ResponseOutput: Codable, Sendable, Equatable {
    public var id: String
    public var role: MessageRole
    public var content: [ResponseContent]

    public init(id: String, role: MessageRole, content: [ResponseContent]) {
        self.id = id
        self.role = role
        self.content = content
    }
}

public enum MessageRole: String, Codable, Sendable {
    case user
    case system
    case assistant
    case tool
    case developer
}

public enum ResponseContent: Codable, Sendable, Equatable {
    case text(TextContent)
    case inputText(TextContent)
    case outputText(TextContent)
    case imageURL(ImageURLContent)
    case toolCall(ResponseToolCall)
    case toolOutput(ResponseToolOutput)
    case unknown(type: String, data: [String: AnyCodable])

    enum CodingKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let singleValue = try decoder.singleValueContainer()
        switch type {
        case "text":
            self = .text(try TextContent(from: decoder))
        case "input_text":
            self = .inputText(try TextContent(from: decoder))
        case "output_text":
            self = .outputText(try TextContent(from: decoder))
        case "image_url":
            self = .imageURL(try ImageURLContent(from: decoder))
        case "tool_call":
            self = .toolCall(try ResponseToolCall(from: decoder))
        case "tool_output":
            self = .toolOutput(try ResponseToolOutput(from: decoder))
        default:
            let raw = try singleValue.decode([String: AnyCodable].self)
            self = .unknown(type: type, data: raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let content):
            try content.encode(to: encoder)
        case .inputText(let content):
            try content.encode(to: encoder)
        case .outputText(let content):
            try content.encode(to: encoder)
        case .imageURL(let content):
            try content.encode(to: encoder)
        case .toolCall(let call):
            try call.encode(to: encoder)
        case .toolOutput(let output):
            try output.encode(to: encoder)
        case .unknown(let type, let data):
            var container = encoder.singleValueContainer()
            var payload = data
            payload["type"] = AnyCodable(type)
            try container.encode(payload)
        }
    }
}

public struct TextContent: Codable, Sendable, Equatable {
    public var type: String
    public var text: String

    public init(type: String, text: String) {
        self.type = type
        self.text = text
    }

    public static func input(_ text: String) -> TextContent { TextContent(type: "input_text", text: text) }
    public static func output(_ text: String) -> TextContent { TextContent(type: "output_text", text: text) }
    public static func plain(_ text: String) -> TextContent { TextContent(type: "text", text: text) }
}

public struct ImageURLContent: Codable, Sendable, Equatable {
    public struct File: Codable, Sendable, Equatable {
        public var url: URL
        public init(url: URL) { self.url = url }
    }

    public var type: String
    public var imageURL: File

    public init(type: String = "image_url", imageURL: File) {
        self.type = type
        self.imageURL = imageURL
    }

    enum CodingKeys: String, CodingKey {
        case type
        case imageURL = "image_url"
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
                if let data = string.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.json = object.mapValues { AnyCodable($0) }
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
    public var output: String

    public init(type: String = "tool_output", toolCallId: String, output: String) {
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

public struct ResponseObject: Codable, Sendable, Equatable {
    public var id: String
    public var object: String
    public var createdAt: Date
    public var model: String
    public var status: ResponseStatus
    public var usage: ResponseUsage?
    public var output: [ResponseOutput]
    public var metadata: [String: String]?
    public var temperature: Double?

    public init(
        id: String,
        object: String = "response",
        createdAt: Date,
        model: String,
        status: ResponseStatus,
        usage: ResponseUsage? = nil,
        output: [ResponseOutput] = [],
        metadata: [String: String]? = nil,
        temperature: Double? = nil
    ) {
        self.id = id
        self.object = object
        self.createdAt = createdAt
        self.model = model
        self.status = status
        self.usage = usage
        self.output = output
        self.metadata = metadata
        self.temperature = temperature
    }

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case createdAt = "created_at"
        case model
        case status
        case usage
        case output
        case metadata
        case temperature
    }
}

public struct ResponseList: Codable, Sendable, Equatable {
    public var object: String
    public var data: [ResponseObject]
    public var hasMore: Bool
    public var firstId: String?
    public var lastId: String?

    public init(object: String, data: [ResponseObject], hasMore: Bool, firstId: String? = nil, lastId: String? = nil) {
        self.object = object
        self.data = data
        self.hasMore = hasMore
        self.firstId = firstId
        self.lastId = lastId
    }

    enum CodingKeys: String, CodingKey {
        case object
        case data
        case hasMore = "has_more"
        case firstId = "first_id"
        case lastId = "last_id"
    }
}

public struct ResponseCreateRequest: Codable, Sendable, Equatable {
    public var model: String
    public var input: [ResponseInputItem]
    public var metadata: [String: String]?
    public var temperature: Double?
    public var topP: Double?
    public var maxOutputTokens: Int?
    public var tools: [ResponseToolDefinition]?
    public var toolChoice: ToolChoice?
    public var previousResponseId: String?

    public init(
        model: String,
        input: [ResponseInputItem],
        metadata: [String: String]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxOutputTokens: Int? = nil,
        tools: [ResponseToolDefinition]? = nil,
        toolChoice: ToolChoice? = nil,
        previousResponseId: String? = nil
    ) {
        self.model = model
        self.input = input
        self.metadata = metadata
        self.temperature = temperature
        self.topP = topP
        self.maxOutputTokens = maxOutputTokens
        self.tools = tools
        self.toolChoice = toolChoice
        self.previousResponseId = previousResponseId
    }

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case metadata
        case temperature
        case topP = "top_p"
        case maxOutputTokens = "max_output_tokens"
        case tools
        case toolChoice = "tool_choice"
        case previousResponseId = "previous_response_id"
    }
}

public enum ToolChoice: Codable, Sendable, Equatable {
    case none
    case auto
    case required
    case named(String)

    enum CodingKeys: String, CodingKey { case type; case function }

    private struct FunctionPayload: Codable, Sendable, Equatable {
        var name: String
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "none": self = .none
        case "auto": self = .auto
        case "required": self = .required
        case "function":
            let function = try container.decode(FunctionPayload.self, forKey: .function)
            self = .named(function.name)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown tool choice type \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode("none", forKey: .type)
        case .auto:
            try container.encode("auto", forKey: .type)
        case .required:
            try container.encode("required", forKey: .type)
        case .named(let name):
            try container.encode("function", forKey: .type)
            try container.encode(FunctionPayload(name: name), forKey: .function)
        }
    }
}

public enum ResponseInputItem: Codable, Sendable, Equatable {
    case message(role: MessageRole, content: [ResponseContent])

    enum CodingKeys: String, CodingKey { case type; case role; case content }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "message":
            let role = try container.decode(MessageRole.self, forKey: .role)
            let content = try container.decode([ResponseContent].self, forKey: .content)
            self = .message(role: role, content: content)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported input item type \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .message(let role, let content):
            try container.encode("message", forKey: .type)
            try container.encode(role, forKey: .role)
            try container.encode(content, forKey: .content)
        }
    }
}

public struct ResponseStreamChunk: Codable, Sendable, Equatable {
    public var id: String?
    public var type: String
    public var status: ResponseStatus?
    public var item: ResponseOutput?
    public var usage: ResponseUsage?

    public init(id: String? = nil, type: String, status: ResponseStatus? = nil, item: ResponseOutput? = nil, usage: ResponseUsage? = nil) {
        self.id = id
        self.type = type
        self.status = status
        self.item = item
        self.usage = usage
    }
}
