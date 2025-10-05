import EventSource
import Foundation

public actor ResponsesClient {
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

    public func create(request: ResponseCreateRequest) async throws -> ResponseObject {
        let httpRequest = HTTPRequest(method: .post, path: "responses", body: request)
        return try await http.send(httpRequest, encoder: encoder, decoder: decoder)
    }

    public func retrieve(id: String) async throws -> ResponseObject {
        let httpRequest = HTTPRequest<EmptyBody>(method: .get, path: "responses/\(id)")
        return try await http.send(httpRequest, encoder: encoder, decoder: decoder)
    }

    public func list(limit: Int? = nil, order: String? = nil, after: String? = nil, before: String? = nil) async throws -> ResponseList {
        var query: [URLQueryItem] = []
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let order { query.append(URLQueryItem(name: "order", value: order)) }
        if let after { query.append(URLQueryItem(name: "after", value: after)) }
        if let before { query.append(URLQueryItem(name: "before", value: before)) }
        let httpRequest = HTTPRequest<EmptyBody>(method: .get, path: "responses", query: query)
        return try await http.send(httpRequest, encoder: encoder, decoder: decoder)
    }

    public func cancel(id: String) async throws -> ResponseObject {
        let httpRequest = HTTPRequest<EmptyBody>(method: .post, path: "responses/\(id)/cancel")
        return try await http.send(httpRequest, encoder: encoder, decoder: decoder)
    }

    public func delete(id: String) async throws -> ResponseDeletion {
        let httpRequest = HTTPRequest<EmptyBody>(method: .delete, path: "responses/\(id)")
        return try await http.send(httpRequest, encoder: encoder, decoder: decoder)
    }

    public func stream(request: ResponseCreateRequest) throws -> AsyncThrowingStream<ResponseStreamEvent, Error> {
        let headers = [
            "Accept": "text/event-stream",
            "Cache-Control": "no-cache"
        ]
        let httpRequest = HTTPRequest(
            method: .post,
            path: "responses",
            query: [URLQueryItem(name: "stream", value: "true")],
            headers: headers,
            body: request
        )
        let eventStream = http.sendStream(httpRequest, encoder: encoder)
        return ResponseStreamParser(decoder: decoder).parse(stream: eventStream)
    }
}

public struct ResponseDeletion: Codable, Sendable, Equatable {
    public var id: String
    public var object: String
    public var deleted: Bool
}

struct ResponseStreamParser {
    private let decoder: JSONDecoder

    init(decoder: JSONDecoder) {
        self.decoder = decoder
    }

    func parse(stream: AsyncThrowingStream<EventSource.Event, Error>) -> AsyncThrowingStream<ResponseStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await event in stream {
                        let trimmed = event.data.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }
                        if trimmed == "[DONE]" {
                            continuation.yield(ResponseStreamEvent(type: "done", data: [:]))
                            continue
                        }
                        guard let jsonData = trimmed.data(using: .utf8) else { continue }
                        do {
                            let dictionary = try decoder.decode([String: AnyCodable].self, from: jsonData)
                            let eventType = event.event
                                ?? dictionary["type"]?.stringValue
                                ?? dictionary["event"]?.stringValue
                                ?? "message"
                            continuation.yield(ResponseStreamEvent(type: eventType, data: dictionary))
                        } catch {
                            let errorPayload: [String: AnyCodable] = [
                                "type": AnyCodable("error"),
                                "message": AnyCodable("chunk_decoding_failed")
                            ]
                            continuation.yield(ResponseStreamEvent(type: "error", data: errorPayload))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
