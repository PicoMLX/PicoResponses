import EventSource
import Foundation

struct HTTPRequest<Body: Encodable & Sendable>: Sendable {
    enum Method: String { case get = "GET", post = "POST", delete = "DELETE", patch = "PATCH" }

    let method: Method
    let path: String
    let query: [URLQueryItem]?
    let headers: [String: String]?
    let body: Body?

    init(
        method: Method,
        path: String,
        query: [URLQueryItem]? = nil,
        headers: [String: String]? = nil,
        body: Body? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
    }
}

final class HTTPClient: @unchecked Sendable {
    let configuration: PicoResponsesConfiguration
    private let session: URLSession
    private let streamConfiguration: URLSessionConfiguration

    init(configuration: PicoResponsesConfiguration) {
        self.configuration = configuration
        let requestConfig = URLSessionConfiguration.default
        requestConfig.timeoutIntervalForRequest = configuration.timeout
        requestConfig.timeoutIntervalForResource = configuration.timeout
        self.session = URLSession(configuration: requestConfig)

        let streamTimeout = configuration.streamingTimeout ?? configuration.timeout
        let streamConfig = URLSessionConfiguration.default
        streamConfig.timeoutIntervalForRequest = streamTimeout
        streamConfig.timeoutIntervalForResource = streamTimeout
        streamConfig.waitsForConnectivity = true
        self.streamConfiguration = streamConfig
    }

    func send<Body: Encodable, Response: Decodable & Sendable>(
        _ request: HTTPRequest<Body>,
        encoder: JSONEncoder,
        decoder: JSONDecoder
    ) async throws -> Response {
        let urlRequest = try makeURLRequest(for: request, encoder: encoder)
        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PicoResponsesError.networkError(underlying: URLError(.badServerResponse))
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw makeAPIError(statusCode: httpResponse.statusCode, data: data)
            }
            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw PicoResponsesError.responseDecodingFailed(underlying: error)
            }
        } catch {
            if let error = error as? PicoResponsesError { throw error }
            throw PicoResponsesError.networkError(underlying: error)
        }
    }

    func sendStream<Body: Encodable>(
        _ request: HTTPRequest<Body>,
        encoder: JSONEncoder
    ) -> AsyncThrowingStream<EventSource.Event, Error> {
        AsyncThrowingStream { continuation in
            let state = EventStreamState()

            Task {
                do {
                    let urlRequest = try makeURLRequest(for: request, encoder: encoder)
                    let eventSource = EventSource(request: urlRequest, configuration: streamConfiguration)
                    await state.setEventSource(eventSource)

                    eventSource.onMessage = { event in
                        continuation.yield(event)
                    }

                    eventSource.onError = { error in
                        Task {
                            if let eventError = error as? EventSourceError,
                               case let .invalidHTTPStatus(status) = eventError {
                                do {
                                    let (data, response) = try await self.session.data(for: urlRequest)
                                    let code = (response as? HTTPURLResponse)?.statusCode ?? status
                                    let apiError = self.makeAPIError(statusCode: code, data: data)
                                    guard let source = await state.markFinished() else {
                                        continuation.finish(throwing: apiError)
                                        return
                                    }
                                    await source.close()
                                    continuation.finish(throwing: apiError)
                                    return
                                } catch let picoError as PicoResponsesError {
                                    guard let source = await state.markFinished() else {
                                        continuation.finish(throwing: picoError)
                                        return
                                    }
                                    await source.close()
                                    continuation.finish(throwing: picoError)
                                    return
                                } catch {
                                    guard let source = await state.markFinished() else {
                                        continuation.finish(throwing: PicoResponsesError.networkError(underlying: error))
                                        return
                                    }
                                    await source.close()
                                    continuation.finish(throwing: PicoResponsesError.networkError(underlying: error))
                                    return
                                }
                            }

                            guard let source = await state.markFinished() else { return }
                            await source.close()
                            guard let error else {
                                continuation.finish()
                                return
                            }
                            if error is CancellationError {
                                continuation.finish()
                            } else {
                                continuation.finish(throwing: self.mapStreamError(error))
                            }
                        }
                    }
                } catch {
                    if let picoError = error as? PicoResponsesError {
                        continuation.finish(throwing: picoError)
                    } else {
                        continuation.finish(throwing: PicoResponsesError.networkError(underlying: error))
                    }
                }
            }

            continuation.onTermination = { _ in
                Task {
                    if let source = await state.cancel() {
                        await source.close()
                    }
                }
            }
        }
    }

    func sendRawData(
        method: HTTPRequest<EmptyBody>.Method,
        path: String,
        query: [URLQueryItem]? = nil,
        headers: [String: String]? = nil
    ) async throws -> Data {
        let request = try makeBaseRequest(
            method: method,
            path: path,
            query: query,
            headers: headers
        )
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PicoResponsesError.networkError(underlying: URLError(.badServerResponse))
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw makeAPIError(statusCode: httpResponse.statusCode, data: data)
            }
            return data
        } catch {
            if let error = error as? PicoResponsesError {
                throw error
            }
            if (error as? CancellationError) != nil {
                throw error
            }
            throw PicoResponsesError.networkError(underlying: error)
        }
    }

    private func mapStreamError(_ error: Error) -> PicoResponsesError {
        if let picoError = error as? PicoResponsesError {
            return picoError
        }
        if let eventError = error as? EventSourceError {
            switch eventError {
            case .invalidHTTPStatus(let status):
                return .httpError(statusCode: status, data: Data())
            case .invalidContentType:
                return .streamDecodingFailed(underlying: eventError)
            }
        }
        if let urlError = error as? URLError {
            return .networkError(underlying: urlError)
        }
        return .networkError(underlying: error)
    }

    private func makeURLRequest<Body: Encodable>(for request: HTTPRequest<Body>, encoder: JSONEncoder) throws -> URLRequest {
        var urlRequest = try makeBaseRequest(
            method: request.method,
            path: request.path,
            query: request.query,
            headers: request.headers
        )
        if let body = request.body {
            do {
                urlRequest.httpBody = try encoder.encode(body)
            } catch {
                throw PicoResponsesError.requestEncodingFailed(underlying: error)
            }
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        return urlRequest
    }

    fileprivate func makeBaseRequest<Body>(
        method: HTTPRequest<Body>.Method,
        path: String,
        query: [URLQueryItem]?,
        headers: [String: String]?
    ) throws -> URLRequest {
        let resolvedURL: URL
        if path.hasPrefix("http") {
            guard let url = URL(string: path) else { throw PicoResponsesError.invalidURL }
            resolvedURL = url
        } else {
            resolvedURL = configuration.baseURL.appendingPathComponent(path)
        }
        var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: true)
        components?.queryItems = query
        guard let url = components?.url else { throw PicoResponsesError.invalidURL }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        headers?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        if let organizationId = configuration.organizationId {
            urlRequest.setValue(organizationId, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let projectId = configuration.projectId {
            urlRequest.setValue(projectId, forHTTPHeaderField: "OpenAI-Project")
        }
        if urlRequest.value(forHTTPHeaderField: "Accept") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        return urlRequest
    }

    func sessionData(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw PicoResponsesError.networkError(underlying: error)
        }
    }

    private func makeAPIError(statusCode: Int, data: Data?) -> PicoResponsesError {
        guard let data, !data.isEmpty else {
            return .httpError(statusCode: statusCode, data: data)
        }
        if let apiError = try? decodeAPIError(from: data) {
            return .apiError(statusCode: statusCode, error: apiError, data: data)
        }
        return .httpError(statusCode: statusCode, data: data)
    }

    private func decodeAPIError(from data: Data) throws -> PicoResponsesAPIError {
        struct Envelope: Decodable {
            let error: PicoResponsesAPIError
        }
        let decoder = JSONDecoder()
        return try decoder.decode(Envelope.self, from: data).error
    }
}

extension HTTPClient {
    struct MultipartPart: Sendable {
        let name: String
        let filename: String?
        let contentType: String?
        let data: Data

        init(name: String, data: Data, filename: String? = nil, contentType: String? = nil) {
            self.name = name
            self.data = data
            self.filename = filename
            self.contentType = contentType
        }
    }

    func sendMultipart(
        method: HTTPRequest<EmptyBody>.Method,
        path: String,
        query: [URLQueryItem]? = nil,
        headers: [String: String]? = nil,
        parts: [MultipartPart]
    ) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        var urlRequest = try makeBaseRequest(
            method: method,
            path: path,
            query: query,
            headers: headers
        )
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let lineBreak = "\r\n"
        for part in parts {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let filename = part.filename {
                disposition += "; filename=\"\(filename)\""
            }
            body.append("\(disposition)\r\n".data(using: .utf8)!)
            if let contentType = part.contentType {
                body.append("Content-Type: \(contentType)\r\n".data(using: .utf8)!)
            }
            body.append("\r\n".data(using: .utf8)!)
            body.append(part.data)
            body.append(lineBreak.data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        do {
            let (data, response) = try await session.upload(for: urlRequest, from: body)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PicoResponsesError.networkError(underlying: URLError(.badServerResponse))
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw makeAPIError(statusCode: httpResponse.statusCode, data: data)
            }
            return data
        } catch {
            if let error = error as? PicoResponsesError {
                throw error
            }
            if (error as? CancellationError) != nil {
                throw error
            }
            throw PicoResponsesError.networkError(underlying: error)
        }
    }
}

private actor EventStreamState {
    private var eventSource: EventSource?
    private var finished = false

    func setEventSource(_ eventSource: EventSource) async {
        guard !finished else {
            await eventSource.close()
            return
        }
        self.eventSource = eventSource
    }

    func markFinished() async -> EventSource? {
        guard !finished else { return nil }
        finished = true
        let source = eventSource
        eventSource = nil
        return source
    }

    func cancel() async -> EventSource? {
        finished = true
        let source = eventSource
        eventSource = nil
        return source
    }
}
