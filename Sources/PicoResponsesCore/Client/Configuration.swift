import Foundation

public struct PicoResponsesConfiguration: Sendable {
    public let apiKey: String?
    public let organizationId: String?
    public let projectId: String?
    public let baseURL: URL
    public let timeout: TimeInterval
    public let streamingTimeout: TimeInterval?

    public init(
        apiKey: String? = nil,
        organizationId: String? = nil,
        projectId: String? = nil,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        timeout: TimeInterval = 120,
        streamingTimeout: TimeInterval? = nil
    ) {
        self.apiKey = apiKey
        self.organizationId = organizationId
        self.projectId = projectId
        self.baseURL = baseURL
        self.timeout = timeout
        self.streamingTimeout = streamingTimeout
    }
}
