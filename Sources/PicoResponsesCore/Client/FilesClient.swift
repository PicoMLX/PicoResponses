import Foundation

public actor FilesClient {
    private let http: HTTPClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(configuration: PicoResponsesConfiguration) {
        self.http = HTTPClient(configuration: configuration)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        self.decoder = decoder
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        self.encoder = encoder
    }

    public func list(limit: Int? = nil, after: String? = nil, before: String? = nil, purpose: FilePurpose? = nil) async throws -> FileList {
        var query: [URLQueryItem] = []
        if let limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let after {
            query.append(URLQueryItem(name: "after", value: after))
        }
        if let before {
            query.append(URLQueryItem(name: "before", value: before))
        }
        if let purpose {
            query.append(URLQueryItem(name: "purpose", value: purpose.rawValue))
        }
        let request = HTTPRequest<EmptyBody>(method: .get, path: "files", query: query.isEmpty ? nil : query)
        return try await http.send(request, encoder: encoder, decoder: decoder)
    }

    public func retrieve(id: String) async throws -> FileObject {
        let request = HTTPRequest<EmptyBody>(method: .get, path: "files/\(id)")
        return try await http.send(request, encoder: encoder, decoder: decoder)
    }

    public func delete(id: String) async throws -> FileDeletion {
        let request = HTTPRequest<EmptyBody>(method: .delete, path: "files/\(id)")
        return try await http.send(request, encoder: encoder, decoder: decoder)
    }

    public func upload(_ payload: FileUploadRequest) async throws -> FileObject {
        let parts: [HTTPClient.MultipartPart] = [
            .init(name: "purpose", data: Data(payload.purpose.rawValue.utf8)),
            .init(
                name: "file",
                data: payload.data,
                filename: payload.filename,
                contentType: payload.mimeType
            )
        ]
        let data = try await http.sendMultipart(
            method: .post,
            path: "files",
            parts: parts
        )
        do {
            return try decoder.decode(FileObject.self, from: data)
        } catch {
            throw PicoResponsesError.responseDecodingFailed(underlying: error)
        }
    }

    public func retrieveContent(id: String) async throws -> Data {
        try await http.sendRawData(
            method: .get,
            path: "files/\(id)/content"
        )
    }
}

public struct FileDeletion: Codable, Sendable, Equatable {
    public var id: String
    public var object: String
    public var deleted: Bool
}
