import Foundation

struct HTTPRequest<Body: Encodable & Sendable>: Sendable {
    enum Method: String { case get = "GET", post = "POST", delete = "DELETE", patch = "PATCH" }

    let method: Method
    let path: String
    let query: [URLQueryItem]?
    let body: Body?

    init(method: Method, path: String, query: [URLQueryItem]? = nil, body: Body? = nil) {
        self.method = method
        self.path = path
        self.query = query
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
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task: URLSessionDataTask
            do {
                let urlRequest = try makeURLRequest(for: request, encoder: encoder)
                let delegate = StreamDelegate(continuation: continuation)
                let streamSession = URLSession(configuration: session.configuration, delegate: delegate, delegateQueue: nil)
                delegate.session = streamSession
                task = streamSession.dataTask(with: urlRequest)
                delegate.task = task
            } catch {
                continuation.finish(throwing: error)
                return
            }
            task.resume()
        }
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
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        if let organizationId = configuration.organizationId {
            urlRequest.setValue(organizationId, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let projectId = configuration.projectId {
            urlRequest.setValue(projectId, forHTTPHeaderField: "OpenAI-Project")
        }
        if let body = request.body {
            do {
                urlRequest.httpBody = try encoder.encode(body)
            } catch {
                throw PicoResponsesError.requestEncodingFailed(underlying: error)
            }
        }
        return urlRequest
    }

    private final class StreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        private let queue = DispatchQueue(label: "PicoResponsesCore.StreamDelegate")
        private let continuation: AsyncThrowingStream<Data, Error>.Continuation
        fileprivate weak var task: URLSessionDataTask?
        fileprivate var session: URLSession?

        init(continuation: AsyncThrowingStream<Data, Error>.Continuation) {
            self.continuation = continuation
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive data: Data
        ) {
            queue.async { [continuation] in
                continuation.yield(data)
            }
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didCompleteWithError error: Error?
        ) {
            queue.async { [continuation] in
                if let error {
                    continuation.finish(throwing: PicoResponsesError.networkError(underlying: error))
                } else {
                    continuation.finish()
                }
                session.invalidateAndCancel()
                self.session = nil
            }
        }
    }

    func sessionData(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw PicoResponsesError.networkError(underlying: error)
        }
    }
}
