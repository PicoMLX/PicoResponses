public struct PicoResponsesCore: Sendable {
    public let configuration: PicoResponsesConfiguration
    public let responses: ResponsesClient
    public let conversations: ConversationsClient
    public let files: FilesClient

    public init(configuration: PicoResponsesConfiguration) {
        self.configuration = configuration
        self.responses = ResponsesClient(configuration: configuration)
        self.conversations = ConversationsClient(configuration: configuration)
        self.files = FilesClient(configuration: configuration)
    }
}
