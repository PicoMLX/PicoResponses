import Foundation
import PicoResponsesCore

public struct ConversationRequestBuilder: Sendable {
    public enum HistoryStrategy: Sendable {
        case latestMessage
        case fullConversation
    }

    public var model: String
    public var instructions: String?
    public var parallelToolCalls: Bool?
    public var metadata: [String: AnyCodable]?
    public var temperature: Double?
    public var topP: Double?
    public var frequencyPenalty: Double?
    public var presencePenalty: Double?
    public var maxOutputTokens: Int?
    public var historyStrategy: HistoryStrategy

    public init(
        model: String,
        instructions: String? = nil,
        parallelToolCalls: Bool? = nil,
        metadata: [String: AnyCodable]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        maxOutputTokens: Int? = nil,
        historyStrategy: HistoryStrategy = .latestMessage
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
        self.historyStrategy = historyStrategy
    }

    public func makeRequest(
        from messages: [ConversationMessage],
        previousResponseId: String?
    ) -> ResponseCreateRequest {
        let inputs: [ResponseInputItem]

        switch historyStrategy {
        case .fullConversation:
            inputs = messages.map(Self.makeInputItem)
        case .latestMessage:
            if let latestUser = messages.last(where: { $0.role == .user && !$0.text.isEmpty }) {
                inputs = [Self.makeInputItem(from: latestUser)]
            } else if let latest = messages.last(where: { !$0.text.isEmpty }) {
                inputs = [Self.makeInputItem(from: latest)]
            } else {
                inputs = []
            }
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
        request.previousResponseId = previousResponseId
        return request
    }

    private static func makeInputItem(from message: ConversationMessage) -> ResponseInputItem {
        ResponseInputItem.message(
            role: message.role.messageRole,
            content: [message.role.contentBlock(text: message.text)]
        )
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

    public func startConversation(
        with messages: [ConversationMessage],
        previousResponseId: String?
    ) async -> AsyncThrowingStream<ConversationStateSnapshot, Error> {
        let request = requestBuilder.makeRequest(from: messages, previousResponseId: previousResponseId)
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
            responsePhase: .awaitingResponse,
            lastResponseId: previousResponseId,
            conversationId: nil,
            createdAt: .distantPast,
            metadata: nil
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

    public func performOneShotConversation(
        with messages: [ConversationMessage],
        previousResponseId: String?
    ) async throws -> ConversationStateSnapshot {
        var request = requestBuilder.makeRequest(from: messages, previousResponseId: previousResponseId)
        request.stream = false
        let response = try await client.create(request: request)
        var snapshot = ConversationStateSnapshot(
            messages: messages,
            responsePhase: .completed,
            webSearchPhase: .none,
            fileSearchPhase: .none,
            reasoningPhase: .none,
            toolCallPhase: .none,
            lastResponseId: response.id,
            conversationId: response.conversationId,
            createdAt: response.createdAt,
            metadata: response.metadata
        )
        snapshot.messages = ConversationStreamReducer.merge(response: response, into: snapshot.messages)
        return snapshot
    }
}

enum ConversationStreamReducer {
    static func reduce(snapshot: ConversationStateSnapshot, with event: ResponseStreamEvent) -> ConversationStateSnapshot {
        var mutableSnapshot = snapshot

        if let response = event.response {
            applyMetadata(from: response, to: &mutableSnapshot)
        } else if let responseId = event.responseId {
            mutableSnapshot.lastResponseId = responseId
        }

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
                applyMetadata(from: response, to: &mutableSnapshot)
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
            mutableMessages[lastIndex].createdAt = Date()
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
            aggregatedMessages.append(
                ConversationMessage(
                    role: messageRole,
                    text: text,
                    createdAt: response.createdAt
                )
            )
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
        } else if type.hasPrefix("response.reasoning") || type.hasPrefix("response.reasoning_") {
            snapshot.reasoningPhase = mapReasoningPhase(type: type, event: event, current: snapshot.reasoningPhase)
        } else if type.hasPrefix("response.tool_call") || type.hasPrefix("response.code_interpreter_call") {
            snapshot.toolCallPhase = mapToolCallPhase(type: type, event: event, current: snapshot.toolCallPhase)
        } else if type.hasPrefix("response.output_item") {
            updateOutputItemStates(type: type, event: event, snapshot: &snapshot)
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
        mapReasoningPhase(type: type, event: event, item: event.data["item"]?.dictionaryValue, current: current)
    }

    private static func mapReasoningPhase(type: String, event: ResponseStreamEvent, item: [String: AnyCodable]?, current: ConversationReasoningPhase) -> ConversationReasoningPhase {
        if containsFailureIndicator(in: type) {
            return .failed(reason: extractReasoningFailureMessage(from: event, item: item))
        }

        if containsCompletionIndicator(in: type) {
            let summary = extractReasoningSummary(from: event, item: item)
            return .completed(summary: summary)
        }

        if containsProgressIndicator(in: type) {
            return .reasoning
        }

        if containsCreationIndicator(in: type) {
            return .drafting
        }

        return current
    }

    private static func mapToolCallPhase(type: String, event: ResponseStreamEvent, current: ConversationToolCallPhase) -> ConversationToolCallPhase {
        mapToolCallPhase(type: type, dataSource: event.data, item: event.data["item"]?.dictionaryValue, current: current)
    }

    private static func mapToolCallPhase(type: String, dataSource: [String: AnyCodable], item: [String: AnyCodable]?, current: ConversationToolCallPhase) -> ConversationToolCallPhase {
        let name = stringValue(for: "name", dataSource: dataSource, item: item)
        let callType = stringValue(for: "type", dataSource: dataSource, item: item)

        if containsFailureIndicator(in: type) {
            let reason = stringValue(for: "error", dataSource: dataSource, item: item) ?? stringValue(for: "message", dataSource: dataSource, item: item)
            return .failed(name: name, callType: callType, reason: reason)
        }

        if containsCompletionIndicator(in: type) {
            return .completed(name: name, callType: callType)
        }

        if containsCreationIndicator(in: type) || type.contains(".delta") {
            return .running(name: name, callType: callType)
        }

        if type.contains(".output") {
            return .awaitingOutput(name: name, callType: callType)
        }

        return current
    }

    private static func extractReasoningSummary(from event: ResponseStreamEvent, item: [String: AnyCodable]?) -> String? {
        if let summary = item?["summary"] ?? event.data["summary"], let text = summary.stringValue {
            return text
        }
        if let array = (item?["summary"] ?? event.data["summary"])?.arrayValue {
            for entry in array {
                if let string = entry.stringValue, !string.isEmpty {
                    return string
                }
                if let dict = entry.dictionaryValue, let text = dict["text"]?.stringValue, !text.isEmpty {
                    return text
                }
            }
        }
        if let summaryDict = (item?["summary"] ?? event.data["summary"])?.dictionaryValue,
           let text = summaryDict["text"]?.stringValue, !text.isEmpty {
            return text
        }
        if let text = (item?["text"] ?? event.data["text"])?.stringValue, !text.isEmpty {
            return text
        }
        return nil
    }

    private static func extractReasoningFailureMessage(from event: ResponseStreamEvent, item: [String: AnyCodable]?) -> String? {
        if let errorDict = (item?["error"] ?? event.data["error"])?.dictionaryValue {
            return errorDict["message"]?.stringValue ?? errorDict["reason"]?.stringValue
        }
        return (item?["error"] ?? event.data["error"])?.stringValue ?? (item?["message"] ?? event.data["message"])?.stringValue
    }

    private static func updateOutputItemStates(type: String, event: ResponseStreamEvent, snapshot: inout ConversationStateSnapshot) {
        guard let item = event.data["item"]?.dictionaryValue,
              let itemType = item["type"]?.stringValue else {
            return
        }

        if itemType.hasPrefix("reasoning") {
            snapshot.reasoningPhase = mapReasoningPhase(type: type, event: event, item: item, current: snapshot.reasoningPhase)
        } else if itemType == "tool_call" || itemType == "code_interpreter_call" {
            snapshot.toolCallPhase = mapToolCallPhase(type: type, dataSource: event.data, item: item, current: snapshot.toolCallPhase)
        }
    }

    private static func containsFailureIndicator(in type: String) -> Bool {
        type.contains(".failed") || type.contains(".error") || type.contains(".cancelled")
    }

    private static func containsCompletionIndicator(in type: String) -> Bool {
        type.contains(".completed") || type.contains(".done") || type.contains(".finished")
    }

    private static func containsProgressIndicator(in type: String) -> Bool {
        type.contains(".delta") || type.contains(".in_progress") || type.contains(".progress")
    }

    private static func containsCreationIndicator(in type: String) -> Bool {
        type.contains(".created") || type.contains(".added") || type.contains(".started")
    }

    private static func stringValue(for key: String, dataSource: [String: AnyCodable], item: [String: AnyCodable]?) -> String? {
        if let itemValue = item?[key]?.stringValue, !itemValue.isEmpty {
            return itemValue
        }
        if let eventValue = dataSource[key]?.stringValue, !eventValue.isEmpty {
            return eventValue
        }
        return nil
    }
}

private extension ConversationStreamReducer {
    static func applyMetadata(from response: ResponseObject, to snapshot: inout ConversationStateSnapshot) {
        snapshot.lastResponseId = response.id
        if let conversationId = response.conversationId, !conversationId.isEmpty {
            snapshot.conversationId = conversationId
        }
        snapshot.createdAt = max(snapshot.createdAt, response.createdAt)
        snapshot.metadata = response.metadata
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
