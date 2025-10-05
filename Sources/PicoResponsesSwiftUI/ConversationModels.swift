import Foundation

public enum ConversationResponsePhase: Sendable, Equatable {
    case idle
    case submitting
    case streaming
    case completed
    case failed
}

public enum ConversationWebSearchState: Sendable, Equatable {
    case none
    case initiated
    case searching
    case completed
    case failed
}

public enum ConversationFileSearchState: Sendable, Equatable {
    case none
    case indexing
    case searching
    case completed
    case failed
}

public enum ConversationReasoningState: Sendable, Equatable {
    case none
    case planning
    case reasoning
    case completed
    case failed
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

public struct ConversationServiceResult: Sendable, Equatable {
    public var messages: [ConversationMessage]
    public var webSearch: ConversationWebSearchState
    public var fileSearch: ConversationFileSearchState
    public var reasoning: ConversationReasoningState

    public init(
        messages: [ConversationMessage] = [],
        webSearch: ConversationWebSearchState = .none,
        fileSearch: ConversationFileSearchState = .none,
        reasoning: ConversationReasoningState = .none
    ) {
        self.messages = messages
        self.webSearch = webSearch
        self.fileSearch = fileSearch
        self.reasoning = reasoning
    }
}

public protocol ConversationService: Sendable {
    func sendPrompt(_ prompt: String) async throws -> ConversationServiceResult
}

public struct PreviewConversationService: ConversationService {
    public init() {}

    public func sendPrompt(_ prompt: String) async throws -> ConversationServiceResult {
        let response = ConversationMessage(role: .assistant, text: "Echo: \(prompt)")
        return ConversationServiceResult(messages: [response])
    }
}
