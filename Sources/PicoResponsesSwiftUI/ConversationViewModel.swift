import Foundation
import Observation

@MainActor
@Observable
public final class ConversationViewModel: Identifiable {
    public let id: UUID
    public private(set) var snapshot: ConversationStateSnapshot
    public private(set) var isStreaming: Bool
    public private(set) var isCancelling: Bool
    public private(set) var lastObservedError: String?

    public var draft: String

    private let service: ConversationService
    private var streamingTask: Task<Void, Never>?

    public init(
        service: ConversationService,
        id: UUID = UUID(),
        initialSnapshot: ConversationStateSnapshot = ConversationStateSnapshot(),
        initialDraft: String = ""
    ) {
        self.service = service
        self.id = id
        self.snapshot = initialSnapshot
        self.draft = initialDraft
        self.isStreaming = false
        self.isCancelling = false
        self.lastObservedError = nil
    }

    public convenience init() {
        self.init(service: PreviewConversationService())
    }

    public func submitPrompt() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMessage = ConversationMessage(role: .user, text: trimmed)
        draft = ""
        
        let previousResponseId = snapshot.lastResponseId
        snapshot.messages.append(userMessage)
        snapshot.responsePhase = .preparing
        snapshot.webSearchPhase = .none
        snapshot.fileSearchPhase = .none
        snapshot.reasoningPhase = .none
        snapshot.toolCallPhase = .none
        lastObservedError = nil

        streamingTask?.cancel()
        let messages = snapshot.messages
        streamingTask = Task { [weak self] in
            await self?.streamConversation(with: messages, previousResponseId: previousResponseId)
        }
    }

    public func submitOneShotPrompt() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ConversationMessage(role: .user, text: trimmed)
        draft = ""

        let previousResponseId = snapshot.lastResponseId
        snapshot.messages.append(userMessage)
        snapshot.responsePhase = .preparing
        snapshot.webSearchPhase = .none
        snapshot.fileSearchPhase = .none
        snapshot.reasoningPhase = .none
        snapshot.toolCallPhase = .none
        lastObservedError = nil

        streamingTask?.cancel()
        let messages = snapshot.messages
        streamingTask = Task { [weak self] in
            await self?.performOneShot(with: messages, previousResponseId: previousResponseId)
        }
    }

    public func cancelStreaming() {
        guard isStreaming else { return }
        isCancelling = true
        streamingTask?.cancel()
        Task {
            await service.cancelActiveConversation()
            await MainActor.run {
                isStreaming = false
                isCancelling = false
                snapshot.responsePhase = .paused
            }
        }
    }

    public func resetConversation() {
        streamingTask?.cancel()
        snapshot = ConversationStateSnapshot()
        draft = ""
        isStreaming = false
        isCancelling = false
        lastObservedError = nil
    }

    private func streamConversation(
        with messages: [ConversationMessage],
        previousResponseId: String?
    ) async {
        let stream = await service.startConversation(with: messages, previousResponseId: previousResponseId)
        await MainActor.run {
            isStreaming = true
            snapshot.responsePhase = .awaitingResponse
        }

        do {
            for try await update in stream {
                await MainActor.run {
                    self.snapshot = update
                    self.isStreaming = update.responsePhase.isStreaming
                    if case .failed(let message) = update.responsePhase {
                        self.lastObservedError = message
                    }
                }
            }
            await MainActor.run {
                isStreaming = false
                isCancelling = false
            }
        } catch {
            if Task.isCancelled {
                return
            }
            await MainActor.run {
                lastObservedError = error.localizedDescription
                snapshot.responsePhase = .failed(error: error.localizedDescription)
                isStreaming = false
                isCancelling = false
            }
        }
    }

    private func performOneShot(
        with messages: [ConversationMessage],
        previousResponseId: String?
    ) async {
        do {
            let snapshot = try await service.performOneShotConversation(
                with: messages,
                previousResponseId: previousResponseId
            )
            await MainActor.run {
                self.snapshot = snapshot
                self.isStreaming = false
                self.isCancelling = false
            }
        } catch {
            if Task.isCancelled {
                return
            }
            await MainActor.run {
                lastObservedError = error.localizedDescription
                self.snapshot.responsePhase = .failed(error: error.localizedDescription)
                isStreaming = false
                isCancelling = false
            }
        }
    }
}
