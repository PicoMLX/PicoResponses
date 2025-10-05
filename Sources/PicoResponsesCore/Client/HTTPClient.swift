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

    init(configuration: PicoResponsesConfiguration) {
        self.configuration = configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeout
        config.timeoutIntervalForResource = configuration.timeout
        self.session = URLSession(configuration: config)
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
                throw PicoResponsesError.httpError(statusCode: httpResponse.statusCode, data: data)
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
                    let eventSource = EventSource(request: urlRequest, configuration: session.configuration)
                    await state.setEventSource(eventSource)

                    eventSource.onMessage = { event in
                        continuation.yield(event)
                    }

                    eventSource.onError = { error in
                        Task {
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
        let resolvedURL: URL
        if request.path.hasPrefix("http") {
            guard let url = URL(string: request.path) else { throw PicoResponsesError.invalidURL }
            resolvedURL = url
        } else {
            resolvedURL = configuration.baseURL.appendingPathComponent(request.path)
        }
        var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: true)
        components?.queryItems = request.query
        guard let url = components?.url else { throw PicoResponsesError.invalidURL }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        request.headers?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        if let organizationId = configuration.organizationId {
            urlRequest.setValue(organizationId, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let projectId = configuration.projectId {
            urlRequest.setValue(projectId, forHTTPHeaderField: "OpenAI-Project")
        }
        if urlRequest.value(forHTTPHeaderField: "Accept") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        }
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

    func sessionData(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
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
