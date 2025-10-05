import Foundation

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

public struct ResponseToolInvocationError: Codable, Sendable, Equatable {
    public var code: String?
    public var message: String?
    public var type: String?
    public var raw: [String: AnyCodable]

    public init(code: String? = nil, message: String? = nil, type: String? = nil, raw: [String: AnyCodable] = [:]) {
        self.code = code
        self.message = message
        self.type = type
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: AnyCodable].self)
        self.code = raw["code"]?.stringValue
        self.message = raw["message"]?.stringValue
        self.type = raw["type"]?.stringValue ?? raw["kind"]?.stringValue
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
    public struct MCPServer: Codable, Sendable, Equatable {
        public var label: String?
        public var url: URL?
        public var transport: String?
        public var version: String?
        public var auth: [String: AnyCodable]?
        public var options: [String: AnyCodable]?
        public var metadata: [String: AnyCodable]?

        enum CodingKeys: String, CodingKey {
            case label
            case url
            case transport
            case version
            case auth
            case options
            case metadata
        }

        public init(
            label: String? = nil,
            url: URL? = nil,
            transport: String? = nil,
            version: String? = nil,
            auth: [String: AnyCodable]? = nil,
            options: [String: AnyCodable]? = nil,
            metadata: [String: AnyCodable]? = nil
        ) {
            self.label = label
            self.url = url
            self.transport = transport
            self.version = version
            self.auth = auth
            self.options = options
            self.metadata = metadata
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.label = try container.decodeIfPresent(String.self, forKey: .label)
            if let urlString = try container.decodeIfPresent(String.self, forKey: .url) {
                self.url = URL(string: urlString)
            } else {
                self.url = nil
            }
            self.transport = try container.decodeIfPresent(String.self, forKey: .transport)
            self.version = try container.decodeIfPresent(String.self, forKey: .version)
            self.auth = try container.decodeIfPresent([String: AnyCodable].self, forKey: .auth)
            self.options = try container.decodeIfPresent([String: AnyCodable].self, forKey: .options)
            self.metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(label, forKey: .label)
            if let url {
                try container.encode(url.absoluteString, forKey: .url)
            }
            try container.encodeIfPresent(transport, forKey: .transport)
            try container.encodeIfPresent(version, forKey: .version)
            try container.encodeIfPresent(auth, forKey: .auth)
            try container.encodeIfPresent(options, forKey: .options)
            try container.encodeIfPresent(metadata, forKey: .metadata)
        }
    }

    public var type: String
    public var name: String
    public var description: String?
    public var inputSchema: JSONSchema
    public var mcpServer: MCPServer?

    public init(
        type: String = "function",
        name: String,
        description: String? = nil,
        inputSchema: JSONSchema,
        mcpServer: MCPServer? = nil
    ) {
        self.type = type
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.mcpServer = mcpServer
    }

    enum CodingKeys: String, CodingKey {
        case type
        case name
        case description
        case inputSchema = "parameters"
        case server
        case serverLabel = "server_label"
        case serverURL = "server_url"
        case serverTransport = "server_transport"
        case serverVersion = "server_version"
        case serverAuth = "server_auth"
        case serverOptions = "server_options"
        case serverMetadata = "server_metadata"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "function"
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.inputSchema = try container.decode(JSONSchema.self, forKey: .inputSchema)

        if let nested = try container.decodeIfPresent(MCPServer.self, forKey: .server) {
            self.mcpServer = nested
        } else {
            let label = try container.decodeIfPresent(String.self, forKey: .serverLabel)
            let urlString = try container.decodeIfPresent(String.self, forKey: .serverURL)
            let transport = try container.decodeIfPresent(String.self, forKey: .serverTransport)
            let version = try container.decodeIfPresent(String.self, forKey: .serverVersion)
            let auth = try container.decodeIfPresent([String: AnyCodable].self, forKey: .serverAuth)
            let options = try container.decodeIfPresent([String: AnyCodable].self, forKey: .serverOptions)
            let metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .serverMetadata)
            if label != nil || urlString != nil || transport != nil || version != nil || auth != nil || options != nil || metadata != nil {
                let url = urlString.flatMap(URL.init(string:))
                self.mcpServer = MCPServer(
                    label: label,
                    url: url,
                    transport: transport,
                    version: version,
                    auth: auth,
                    options: options,
                    metadata: metadata
                )
            } else {
                self.mcpServer = nil
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(inputSchema, forKey: .inputSchema)

        if let mcpServer {
            try container.encode(mcpServer, forKey: .server)
            try container.encodeIfPresent(mcpServer.label, forKey: .serverLabel)
            if let url = mcpServer.url {
                try container.encode(url.absoluteString, forKey: .serverURL)
            }
            try container.encodeIfPresent(mcpServer.transport, forKey: .serverTransport)
            try container.encodeIfPresent(mcpServer.version, forKey: .serverVersion)
            try container.encodeIfPresent(mcpServer.auth, forKey: .serverAuth)
            try container.encodeIfPresent(mcpServer.options, forKey: .serverOptions)
            try container.encodeIfPresent(mcpServer.metadata, forKey: .serverMetadata)
        }
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

        public var dictionaryValue: [String: AnyCodable]? {
            if let json {
                return json
            }
            guard
                let string,
                let data = string.data(using: .utf8),
                let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                return nil
            }
            return jsonObject.mapValues { AnyCodable($0) }
        }
    }

    public var type: String
    public var id: String
    public var name: String
    public var arguments: Arguments
    public var status: String?
    public var startedAt: Date?
    public var completedAt: Date?
    public var metadata: [String: AnyCodable]?
    public var executionContext: [String: AnyCodable]?
    public var fileIds: [String]?
    public var error: ResponseToolInvocationError?

    public init(
        type: String = "tool_call",
        id: String,
        name: String,
        arguments: Arguments,
        status: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        metadata: [String: AnyCodable]? = nil,
        executionContext: [String: AnyCodable]? = nil,
        fileIds: [String]? = nil,
        error: ResponseToolInvocationError? = nil
    ) {
        self.type = type
        self.id = id
        self.name = name
        self.arguments = arguments
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.metadata = metadata
        self.executionContext = executionContext
        self.fileIds = fileIds
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case name
        case arguments
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case metadata
        case executionContext = "execution_context"
        case fileIds = "file_ids"
        case error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "tool_call"
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.arguments = try container.decode(Arguments.self, forKey: .arguments)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        self.startedAt = ResponseToolCall.decodeTimestamp(in: container, forKey: .startedAt)
        self.completedAt = ResponseToolCall.decodeTimestamp(in: container, forKey: .completedAt)
        self.metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
        self.executionContext = try container.decodeIfPresent([String: AnyCodable].self, forKey: .executionContext)
        self.fileIds = try container.decodeIfPresent([String].self, forKey: .fileIds)
        self.error = try container.decodeIfPresent(ResponseToolInvocationError.self, forKey: .error)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(arguments, forKey: .arguments)
        try container.encodeIfPresent(status, forKey: .status)
        if let startedAt {
            try container.encode(startedAt.timeIntervalSince1970, forKey: .startedAt)
        }
        if let completedAt {
            try container.encode(completedAt.timeIntervalSince1970, forKey: .completedAt)
        }
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(executionContext, forKey: .executionContext)
        try container.encodeIfPresent(fileIds, forKey: .fileIds)
        try container.encodeIfPresent(error, forKey: .error)
    }

    private static func decodeTimestamp(
        in container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Date? {
        if let seconds = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: seconds)
        }
        if let secondsInt = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Date(timeIntervalSince1970: TimeInterval(secondsInt))
        }
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            if let seconds = Double(stringValue) {
                return Date(timeIntervalSince1970: seconds)
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: stringValue) {
                return date
            }
            return ISO8601DateFormatter().date(from: stringValue)
        }
        if let date = try? container.decodeIfPresent(Date.self, forKey: key) {
            return date
        }
        return nil
    }
}

public struct ResponseToolOutput: Codable, Sendable, Equatable {
    public enum Payload: Codable, Sendable, Equatable {
        case string(String)
        case integer(Int64)
        case number(Double)
        case boolean(Bool)
        case array([AnyCodable])
        case json([String: AnyCodable])
        case null
        case raw(AnyCodable)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let intValue = try? container.decode(Int64.self) {
                self = .integer(intValue)
            } else if let doubleValue = try? container.decode(Double.self) {
                self = .number(doubleValue)
            } else if let boolValue = try? container.decode(Bool.self) {
                self = .boolean(boolValue)
            } else if let jsonArray = try? container.decode([AnyCodable].self) {
                self = .array(jsonArray)
            } else if let jsonObject = try? container.decode([String: AnyCodable].self) {
                self = .json(jsonObject)
            } else {
                let rawValue = try container.decode(AnyCodable.self)
                self = .raw(rawValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value):
                try container.encode(value)
            case .integer(let value):
                try container.encode(value)
            case .number(let value):
                try container.encode(value)
            case .boolean(let value):
                try container.encode(value)
            case .array(let value):
                try container.encode(value)
            case .json(let value):
                try container.encode(value)
            case .null:
                try container.encodeNil()
            case .raw(let value):
                try container.encode(value)
            }
        }

        public var anyCodable: AnyCodable {
            switch self {
            case .string(let value):
                return AnyCodable(value)
            case .integer(let value):
                return AnyCodable(value)
            case .number(let value):
                return AnyCodable(value)
            case .boolean(let value):
                return AnyCodable(value)
            case .array(let value):
                return AnyCodable(value.map { $0.jsonObject })
            case .json(let value):
                return AnyCodable(value.jsonObject())
            case .null:
                return AnyCodable(NSNull())
            case .raw(let value):
                return value
            }
        }

        public var stringValue: String? {
            if case let .string(value) = self { return value }
            return nil
        }

        public var dictionaryValue: [String: AnyCodable]? {
            if case let .json(value) = self { return value }
            return nil
        }
    }

    public var type: String
    public var toolCallId: String
    public var payload: Payload
    public var contentType: String?
    public var metadata: [String: AnyCodable]?
    public var error: ResponseToolInvocationError?

    public init(
        type: String = "tool_output",
        toolCallId: String,
        payload: Payload,
        contentType: String? = nil,
        metadata: [String: AnyCodable]? = nil,
        error: ResponseToolInvocationError? = nil
    ) {
        self.type = type
        self.toolCallId = toolCallId
        self.payload = payload
        self.contentType = contentType
        self.metadata = metadata
        self.error = error
    }

    public var output: AnyCodable {
        payload.anyCodable
    }

    public var stringValue: String? {
        payload.stringValue
    }

    public var jsonValue: [String: AnyCodable]? {
        payload.dictionaryValue
    }

    enum CodingKeys: String, CodingKey {
        case type
        case toolCallId = "tool_call_id"
        case payload = "output"
        case contentType = "content_type"
        case metadata
        case error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "tool_output"
        self.toolCallId = try container.decode(String.self, forKey: .toolCallId)
        self.payload = try container.decode(Payload.self, forKey: .payload)
        self.contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        self.metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
        self.error = try container.decodeIfPresent(ResponseToolInvocationError.self, forKey: .error)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(toolCallId, forKey: .toolCallId)
        try container.encode(payload, forKey: .payload)
        try container.encodeIfPresent(contentType, forKey: .contentType)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(error, forKey: .error)
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
    public var completedAt: Date?
    public var updatedAt: Date?
    public var expiresAt: Date?
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
        completedAt: Date? = nil,
        updatedAt: Date? = nil,
        expiresAt: Date? = nil,
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
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
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
        case completedAt = "completed_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
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
