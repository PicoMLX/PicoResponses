import Foundation
import Observation

@MainActor
@Observable
public final class ConversationViewModel {
    public private(set) var transcript: [ConversationMessage]
    public private(set) var phase: ConversationResponsePhase
    public private(set) var webSearchState: ConversationWebSearchState
    public private(set) var fileSearchState: ConversationFileSearchState
    public private(set) var reasoningState: ConversationReasoningState
    public private(set) var lastErrorDescription: String?

    public var draft: String

    private let service: ConversationService

    public init(
        service: ConversationService,
        initialTranscript: [ConversationMessage] = [],
        initialDraft: String = ""
    ) {
        self.service = service
        self.transcript = initialTranscript
        self.draft = initialDraft
        self.phase = .idle
        self.webSearchState = .none
        self.fileSearchState = .none
        self.reasoningState = .none
        self.lastErrorDescription = nil
    }

    public convenience init() {
        self.init(service: PreviewConversationService())
    }

    public func submitPrompt() async {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        let userMessage = ConversationMessage(role: .user, text: prompt)
        transcript.append(userMessage)
        draft = ""

        phase = .submitting
        lastErrorDescription = nil

        do {
            let result = try await service.sendPrompt(prompt)
            webSearchState = result.webSearch
            fileSearchState = result.fileSearch
            reasoningState = result.reasoning
            transcript.append(contentsOf: result.messages)
            phase = .completed
        } catch {
            lastErrorDescription = error.localizedDescription
            phase = .failed
        }
    }

    public func cancelStreaming() {
        phase = .idle
    }

    public func resetConversation() {
        transcript.removeAll()
        draft = ""
        phase = .idle
        webSearchState = .none
        fileSearchState = .none
        reasoningState = .none
        lastErrorDescription = nil
    }
}
