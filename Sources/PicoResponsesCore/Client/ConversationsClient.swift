import Foundation

public actor ConversationsClient {
    private let http: HTTPClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(configuration: PicoResponsesConfiguration) {
        self.http = HTTPClient(configuration: configuration)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        self.decoder = decoder
        self.encoder = encoder
    }

    public func list(limit: Int? = nil, order: String? = nil, after: String? = nil, before: String? = nil) async throws -> ConversationList {
        var query: [URLQueryItem] = []
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let order { query.append(URLQueryItem(name: "order", value: order)) }
        if let after { query.append(URLQueryItem(name: "after", value: after)) }
        if let before { query.append(URLQueryItem(name: "before", value: before)) }
        let request = HTTPRequest<EmptyBody>(method: .get, path: "conversations", query: query)
        return try await http.send(request, encoder: encoder, decoder: decoder)
    }

    public func retrieve(id: String) async throws -> ConversationObject {
        let request = HTTPRequest<EmptyBody>(method: .get, path: "conversations/\(id)")
        return try await http.send(request, encoder: encoder, decoder: decoder)
    }

    public func create(request body: ConversationCreateRequest) async throws -> ConversationObject {
        let request = HTTPRequest(method: .post, path: "conversations", body: body)
        return try await http.send(request, encoder: encoder, decoder: decoder)
    }

    public func update(id: String, request body: ConversationUpdateRequest) async throws -> ConversationObject {
        let request = HTTPRequest(method: .patch, path: "conversations/\(id)", body: body)
        return try await http.send(request, encoder: encoder, decoder: decoder)
    }

    public func delete(id: String) async throws -> ConversationDeletion {
        let request = HTTPRequest<EmptyBody>(method: .delete, path: "conversations/\(id)")
        return try await http.send(request, encoder: encoder, decoder: decoder)
    }

    public func listItems(conversationId: String, limit: Int? = nil, order: String? = nil, after: String? = nil, before: String? = nil) async throws -> ConversationItemList {
        var query: [URLQueryItem] = []
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let order { query.append(URLQueryItem(name: "order", value: order)) }
        if let after { query.append(URLQueryItem(name: "after", value: after)) }
        if let before { query.append(URLQueryItem(name: "before", value: before)) }
        let request = HTTPRequest<EmptyBody>(method: .get, path: "conversations/\(conversationId)/items", query: query)
        return try await http.send(request, encoder: encoder, decoder: decoder)
    }
}
