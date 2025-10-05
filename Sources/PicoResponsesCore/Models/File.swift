import Foundation

public enum FilePurpose: String, Codable, Sendable {
    case fineTune = "fine-tune"
    case responses
    case assistants
    case vision
    case batch
    case moderation
    case other

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = FilePurpose(rawValue: raw) ?? .other
    }
}

public struct FileObject: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var bytes: Int
    public var createdAt: Date
    public var filename: String
    public var object: String
    public var purpose: FilePurpose
    public var status: String?
    public var statusDetails: [String: AnyCodable]?

    public init(
        id: String,
        bytes: Int,
        createdAt: Date,
        filename: String,
        object: String = "file",
        purpose: FilePurpose,
        status: String? = nil,
        statusDetails: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.bytes = bytes
        self.createdAt = createdAt
        self.filename = filename
        self.object = object
        self.purpose = purpose
        self.status = status
        self.statusDetails = statusDetails
    }

    enum CodingKeys: String, CodingKey {
        case id
        case bytes
        case createdAt = "created_at"
        case filename
        case object
        case purpose
        case status
        case statusDetails = "status_details"
    }
}

public struct FileList: Codable, Sendable, Equatable {
    public var object: String
    public var data: [FileObject]

    public init(object: String = "list", data: [FileObject]) {
        self.object = object
        self.data = data
    }
}

public struct FileUploadRequest: Sendable, Equatable {
    public var purpose: FilePurpose
    public var filename: String
    public var data: Data
    public var mimeType: String

    public init(purpose: FilePurpose, filename: String, data: Data, mimeType: String) {
        self.purpose = purpose
        self.filename = filename
        self.data = data
        self.mimeType = mimeType
    }
}
