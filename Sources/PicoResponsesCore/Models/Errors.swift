import Foundation

public struct PicoResponsesAPIError: Codable, Sendable, Equatable {
    public var message: String?
    public var type: String?
    public var param: String?
    public var code: String?
    public var raw: [String: AnyCodable]

    public init(
        message: String? = nil,
        type: String? = nil,
        param: String? = nil,
        code: String? = nil,
        raw: [String: AnyCodable] = [:]
    ) {
        self.message = message
        self.type = type
        self.param = param
        self.code = code
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: AnyCodable].self)
        self.message = raw["message"]?.stringValue
        self.type = raw["type"]?.stringValue
        self.param = raw["param"]?.stringValue
        self.code = raw["code"]?.stringValue
        self.raw = raw
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

public enum PicoResponsesError: Error, Sendable {
    case invalidURL
    case requestEncodingFailed(underlying: Error)
    case responseDecodingFailed(underlying: Error)
    case httpError(statusCode: Int, data: Data?)
    case apiError(statusCode: Int, error: PicoResponsesAPIError, data: Data?)
    case networkError(underlying: Error)
    case streamDecodingFailed(underlying: Error)
}
