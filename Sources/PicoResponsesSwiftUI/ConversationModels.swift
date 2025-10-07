import Foundation

public enum ConversationResponsePhase: Sendable, Equatable {
    case idle
    case preparing
    case awaitingResponse
    case streaming
    case paused
    case completed
    case failed(error: String)
}

public enum ConversationWebSearchPhase: Sendable, Equatable {
    case none
    case initiated(query: String?)
    case searching
    case analyzing
    case completed
    case failed(reason: String?)
}

public enum ConversationFileSearchPhase: Sendable, Equatable {
    case none
    case preparing
    case searching
    case completed
    case failed(reason: String?)
}

public enum ConversationReasoningPhase: Sendable, Equatable {
    case none
    case drafting
    case reasoning
    case completed(summary: String?)
    case failed(reason: String?)
}

public enum ConversationToolCallPhase: Sendable, Equatable {
    case none
    case running(name: String?, callType: String?)
    case awaitingOutput(name: String?, callType: String?)
    case completed(name: String?, callType: String?)
    case failed(name: String?, callType: String?, reason: String?)
}

public struct ConversationMessage: Identifiable, Equatable, Sendable {
    public enum Role: String, Sendable {
        case user
        case assistant
        case system
        case tool
    }

    public let id: UUID
    public var role: Role
    public var text: String

    public init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

public struct ConversationStateSnapshot: Sendable, Equatable {
    public var messages: [ConversationMessage]
    public var responsePhase: ConversationResponsePhase
    public var webSearchPhase: ConversationWebSearchPhase
    public var fileSearchPhase: ConversationFileSearchPhase
    public var reasoningPhase: ConversationReasoningPhase
    public var toolCallPhase: ConversationToolCallPhase

    public init(
        messages: [ConversationMessage] = [],
        responsePhase: ConversationResponsePhase = .idle,
        webSearchPhase: ConversationWebSearchPhase = .none,
        fileSearchPhase: ConversationFileSearchPhase = .none,
        reasoningPhase: ConversationReasoningPhase = .none,
        toolCallPhase: ConversationToolCallPhase = .none
    ) {
        self.messages = messages
        self.responsePhase = responsePhase
        self.webSearchPhase = webSearchPhase
        self.fileSearchPhase = fileSearchPhase
        self.reasoningPhase = reasoningPhase
        self.toolCallPhase = toolCallPhase
    }
}

public protocol ConversationService: Sendable {
    func startConversation(with messages: [ConversationMessage]) async -> AsyncThrowingStream<ConversationStateSnapshot, Error>
    func cancelActiveConversation() async
    func performOneShotConversation(with messages: [ConversationMessage]) async throws -> ConversationStateSnapshot
}

public struct PreviewConversationService: ConversationService {
    public init() {}

    public func startConversation(with messages: [ConversationMessage]) async -> AsyncThrowingStream<ConversationStateSnapshot, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(
                ConversationStateSnapshot(
                    messages: messages,
                    responsePhase: .awaitingResponse
                )
            )
            let response = ConversationMessage(role: .assistant, text: "Echo: \(messages.last?.text ?? "")")
            let finalSnapshot = ConversationStateSnapshot(
                messages: messages + [response],
                responsePhase: .completed
            )
            continuation.yield(finalSnapshot)
            continuation.finish()
        }
    }

    public func cancelActiveConversation() async {}

    public func performOneShotConversation(with messages: [ConversationMessage]) async throws -> ConversationStateSnapshot {
        let response = ConversationMessage(role: .assistant, text: "Echo: \(messages.last?.text ?? "")")
        return ConversationStateSnapshot(messages: messages + [response], responsePhase: .completed)
    }
}

public extension ConversationResponsePhase {
    var isStreaming: Bool {
        switch self {
        case .awaitingResponse, .streaming:
            return true
        default:
            return false
        }
    }
}
