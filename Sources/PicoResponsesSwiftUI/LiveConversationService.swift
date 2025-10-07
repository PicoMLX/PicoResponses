import Foundation
import PicoResponsesCore

public struct ConversationRequestBuilder: Sendable {
    public var model: String
    public var instructions: String?
    public var parallelToolCalls: Bool?
    public var metadata: [String: AnyCodable]?
    public var temperature: Double?
    public var topP: Double?
    public var frequencyPenalty: Double?
    public var presencePenalty: Double?
    public var maxOutputTokens: Int?

    public init(
        model: String,
        instructions: String? = nil,
        parallelToolCalls: Bool? = nil,
        metadata: [String: AnyCodable]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        maxOutputTokens: Int? = nil
    ) {
        self.model = model
        self.instructions = instructions
        self.parallelToolCalls = parallelToolCalls
        self.metadata = metadata
        self.temperature = temperature
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.maxOutputTokens = maxOutputTokens
    }

    public func makeRequest(from messages: [ConversationMessage]) -> ResponseCreateRequest {
        let inputs = messages.map { message in
            ResponseInputItem.message(
                role: message.role.messageRole,
                content: [message.role.contentBlock(text: message.text)]
            )
        }
        var request = ResponseCreateRequest(model: model, input: inputs)
        request.instructions = instructions
        request.parallelToolCalls = parallelToolCalls
        request.metadata = metadata
        request.temperature = temperature
        request.topP = topP
        request.frequencyPenalty = frequencyPenalty
        request.presencePenalty = presencePenalty
        request.maxOutputTokens = maxOutputTokens
        return request
    }
}

public actor LiveConversationService: ConversationService {
    private let client: ResponsesClient
    private let requestBuilder: ConversationRequestBuilder
    private var activeTask: Task<Void, Never>?

    public init(client: ResponsesClient, requestBuilder: ConversationRequestBuilder) {
        self.client = client
        self.requestBuilder = requestBuilder
    }

    public func startConversation(with messages: [ConversationMessage]) async -> AsyncThrowingStream<ConversationStateSnapshot, Error> {
        let request = requestBuilder.makeRequest(from: messages)
        let responseStream: AsyncThrowingStream<ResponseStreamEvent, Error>
        do {
            responseStream = try await client.stream(request: request)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }

        let initialSnapshot = ConversationStateSnapshot(
            messages: messages,
            responsePhase: .awaitingResponse
        )

        return AsyncThrowingStream { continuation in
            continuation.yield(initialSnapshot)

            var currentSnapshot = initialSnapshot

            let task = Task {
                do {
                    for try await event in responseStream {
                        currentSnapshot = ConversationStreamReducer.reduce(snapshot: currentSnapshot, with: event)
                        continuation.yield(currentSnapshot)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            activeTask?.cancel()
            activeTask = task

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func cancelActiveConversation() async {
        activeTask?.cancel()
        activeTask = nil
    }

    public func performOneShotConversation(with messages: [ConversationMessage]) async throws -> ConversationStateSnapshot {
        var request = requestBuilder.makeRequest(from: messages)
        request.stream = false
        let response = try await client.create(request: request)
        var snapshot = ConversationStateSnapshot(
            messages: messages,
            responsePhase: .completed,
            webSearchPhase: .none,
            fileSearchPhase: .none,
            reasoningPhase: .none
        )
        snapshot.messages = ConversationStreamReducer.merge(response: response, into: snapshot.messages)
        return snapshot
    }
}

enum ConversationStreamReducer {
    static func reduce(snapshot: ConversationStateSnapshot, with event: ResponseStreamEvent) -> ConversationStateSnapshot {
        var mutableSnapshot = snapshot

        switch event.kind {
        case .responseCreated:
            mutableSnapshot.responsePhase = .awaitingResponse
        case .responseInProgress:
            mutableSnapshot.responsePhase = .streaming
        case .responseOutputTextDelta:
            if let text = event.outputTextDelta?.text, !text.isEmpty {
                mutableSnapshot.responsePhase = .streaming
                mutableSnapshot.messages = appendAssistantText(text, to: mutableSnapshot.messages)
            }
        case .responseOutputTextDone:
            if let response = event.response {
                mutableSnapshot.messages = merge(response: response, into: mutableSnapshot.messages)
            }
        case .responseCompleted:
            mutableSnapshot.responsePhase = .completed
            if let response = event.completedResponse {
                mutableSnapshot.messages = merge(response: response, into: mutableSnapshot.messages)
            }
        case .responseError:
            let message = event.streamError?.message ?? "Unknown error"
            mutableSnapshot.responsePhase = .failed(error: message)
        case .done:
            if case .streaming = mutableSnapshot.responsePhase {
                mutableSnapshot.responsePhase = .completed
            }
        case .other(let type):
            updateToolStates(type: type, event: event, snapshot: &mutableSnapshot)
        }

        return mutableSnapshot
    }

    private static func appendAssistantText(_ text: String, to messages: [ConversationMessage]) -> [ConversationMessage] {
        guard !text.isEmpty else { return messages }
        var mutableMessages = messages
        if let lastIndex = mutableMessages.indices.last, mutableMessages[lastIndex].role == .assistant {
            mutableMessages[lastIndex].text.append(text)
        } else {
            mutableMessages.append(ConversationMessage(role: .assistant, text: text))
        }
        return mutableMessages
    }

    static func merge(response: ResponseObject, into messages: [ConversationMessage]) -> [ConversationMessage] {
        var mutableMessages = messages
        var aggregatedMessages: [ConversationMessage] = []

        for output in response.output {
            let text = output.content.compactMap { $0.text }.joined()
            guard !text.isEmpty else { continue }
            guard let role = output.role else { continue }
            let messageRole = ConversationMessage.Role(messageRole: role)
            aggregatedMessages.append(ConversationMessage(role: messageRole, text: text))
        }

        guard !aggregatedMessages.isEmpty else { return mutableMessages }

        if let first = aggregatedMessages.first,
           let lastIndex = mutableMessages.indices.last,
           mutableMessages[lastIndex].role == first.role {
            mutableMessages.remove(at: lastIndex)
        }

        mutableMessages.append(contentsOf: aggregatedMessages)

        return mutableMessages
    }

    private static func updateToolStates(type: String, event: ResponseStreamEvent, snapshot: inout ConversationStateSnapshot) {
        if type.hasPrefix("response.web_search_call") {
            snapshot.webSearchPhase = mapWebSearchPhase(type: type, event: event, current: snapshot.webSearchPhase)
        } else if type.hasPrefix("response.file_search_call") {
            snapshot.fileSearchPhase = mapFileSearchPhase(type: type, event: event, current: snapshot.fileSearchPhase)
        } else if type.hasPrefix("response.reasoning") {
            snapshot.reasoningPhase = mapReasoningPhase(type: type, event: event, current: snapshot.reasoningPhase)
        }
    }

    private static func mapWebSearchPhase(type: String, event: ResponseStreamEvent, current: ConversationWebSearchPhase) -> ConversationWebSearchPhase {
        let query = event.data["query"]?.stringValue
        switch type {
        case "response.web_search_call.created":
            return .initiated(query: query)
        case "response.web_search_call.delta":
            return .searching
        case "response.web_search_call.completed":
            return .completed
        case "response.web_search_call.failed":
            return .failed(reason: event.data["error"]?.stringValue)
        default:
            return current
        }
    }

    private static func mapFileSearchPhase(type: String, event: ResponseStreamEvent, current: ConversationFileSearchPhase) -> ConversationFileSearchPhase {
        switch type {
        case "response.file_search_call.created":
            return .preparing
        case "response.file_search_call.delta":
            return .searching
        case "response.file_search_call.completed":
            return .completed
        case "response.file_search_call.failed":
            return .failed(reason: event.data["error"]?.stringValue)
        default:
            return current
        }
    }

    private static func mapReasoningPhase(type: String, event: ResponseStreamEvent, current: ConversationReasoningPhase) -> ConversationReasoningPhase {
        switch type {
        case "response.reasoning.created":
            return .drafting
        case "response.reasoning.delta":
            return .reasoning
        case "response.reasoning.completed":
            let summary = event.data["summary"]?.stringValue
            return .completed(summary: summary)
        case "response.reasoning.failed":
            return .failed(reason: event.data["error"]?.stringValue)
        default:
            return current
        }
    }
}

private extension ConversationMessage.Role {
    var messageRole: MessageRole {
        switch self {
        case .user:
            return .user
        case .assistant:
            return .assistant
        case .system:
            return .system
        case .tool:
            return .tool
        }
    }

    func contentBlock(text: String) -> ResponseContentBlock {
        switch self {
        case .assistant:
            return .outputText(text)
        default:
            return .inputText(text)
        }
    }
}

private extension ConversationMessage.Role {
    init(messageRole: MessageRole) {
        switch messageRole {
        case .user:
            self = .user
        case .assistant:
            self = .assistant
        case .system, .developer:
            self = .system
        case .tool:
            self = .tool
        }
    }
}
