import Foundation

public actor FilesClient {
    private let http: HTTPClient
    private let decoder: JSONDecoder

    public init(configuration: PicoResponsesConfiguration) {
        self.http = HTTPClient(configuration: configuration)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        self.decoder = decoder
    }

    public func list() async throws -> FileList {
        let request = HTTPRequest<EmptyBody>(method: .get, path: "files")
        return try await http.send(request, encoder: JSONEncoder(), decoder: decoder)
    }

    public func retrieve(id: String) async throws -> FileObject {
        let request = HTTPRequest<EmptyBody>(method: .get, path: "files/\(id)")
        return try await http.send(request, encoder: JSONEncoder(), decoder: decoder)
    }

    public func delete(id: String) async throws -> FileDeletion {
        let request = HTTPRequest<EmptyBody>(method: .delete, path: "files/\(id)")
        return try await http.send(request, encoder: JSONEncoder(), decoder: decoder)
    }

    public func upload(_ payload: FileUploadRequest) async throws -> FileObject {
        let request = try makeMultipartRequest(path: "files", payload: payload)
        let (data, response) = try await http.sessionData(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PicoResponsesError.networkError(underlying: URLError(.badServerResponse))
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PicoResponsesError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        do {
            return try decoder.decode(FileObject.self, from: data)
        } catch {
            throw PicoResponsesError.responseDecodingFailed(underlying: error)
        }
    }

    public func retrieveContent(id: String) async throws -> Data {
        let configuration = http.configuration
        let url = configuration.baseURL.appendingPathComponent("files/\(id)/content")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request)
        let (data, response) = try await http.sessionData(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PicoResponsesError.networkError(underlying: URLError(.badServerResponse))
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PicoResponsesError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        return data
    }

    private func makeMultipartRequest(path: String, payload: FileUploadRequest) throws -> URLRequest {
        let configuration = http.configuration
        let url = configuration.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthHeaders(to: &request)

        var body = Data()
        let lineBreak = "\r\n"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(payload.purpose.rawValue)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(payload.filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(payload.mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(payload.data)
        body.append(lineBreak.data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        return request
    }

    private func applyAuthHeaders(to request: inout URLRequest) {
        let configuration = http.configuration
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        if let organizationId = configuration.organizationId {
            request.setValue(organizationId, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let projectId = configuration.projectId {
            request.setValue(projectId, forHTTPHeaderField: "OpenAI-Project")
        }
    }
}

public struct FileDeletion: Codable, Sendable, Equatable {
    public var id: String
    public var object: String
    public var deleted: Bool
}
