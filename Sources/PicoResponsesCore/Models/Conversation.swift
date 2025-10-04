import Foundation

public struct ConversationObject: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var object: String
    public var createdAt: Date
    public var updatedAt: Date
    public var metadata: [String: String]?

    public init(id: String, object: String = "conversation", createdAt: Date, updatedAt: Date, metadata: [String: String]? = nil) {
        self.id = id
        self.object = object
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case metadata
    }
}

public struct ConversationList: Codable, Sendable, Equatable {
    public var object: String
    public var data: [ConversationObject]
    public var hasMore: Bool
    public var firstId: String?
    public var lastId: String?

    public init(object: String = "list", data: [ConversationObject], hasMore: Bool, firstId: String? = nil, lastId: String? = nil) {
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

public struct ConversationItemList: Codable, Sendable, Equatable {
    public var object: String
    public var data: [ResponseOutput]
    public var hasMore: Bool
    public var firstId: String?
    public var lastId: String?

    public init(object: String = "list", data: [ResponseOutput], hasMore: Bool, firstId: String? = nil, lastId: String? = nil) {
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

public struct ConversationCreateRequest: Codable, Sendable, Equatable {
    public var metadata: [String: String]?
    public var title: String?

    public init(metadata: [String: String]? = nil, title: String? = nil) {
        self.metadata = metadata
        self.title = title
    }
}

public struct ConversationUpdateRequest: Codable, Sendable, Equatable {
    public var metadata: [String: String]?
    public var title: String?
    public init(metadata: [String: String]? = nil, title: String? = nil) {
        self.metadata = metadata
        self.title = title
    }
}

public struct ConversationDeletion: Codable, Sendable, Equatable {
    public var id: String
    public var object: String
    public var deleted: Bool
}
