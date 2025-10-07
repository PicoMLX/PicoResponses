//
//  SwiftUIView.swift
//  PicoResponses
//
//  Created by Ronald Mannak on 10/5/25.
//

import SwiftUI
import PicoResponsesSwiftUI

struct ConversationView: View {
    
    @State var conversation: ConversationViewModel
    
    var body: some View {
        
        VStack(spacing: 0) {
        
            List {
                ForEach(conversation.snapshot.messages) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.role.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(message.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .listRowSeparator(.hidden)
                }
                if let errorMessage = conversation.lastObservedError,
                   case .failed = conversation.snapshot.responsePhase {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                let statuses = statusMessages
                if !statuses.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(statuses, id: \.self) { message in
                                Text(message)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            
            // MARK: - Compose bar
            
            ComposeView(text: $conversation.draft, isSending: conversation.isStreaming) {
                print("hit send for prompt: \(conversation.draft)")
//                conversation.submitOneShotPrompt() // non-streaming
                conversation.submitPrompt() // streaming
            }
        }
    }
}

private extension ConversationView {
    var statusMessages: [String] {
        var messages: [String] = []
        let _ = Self._printChanges()

        switch conversation.snapshot.responsePhase {
        case .preparing:
            messages.append("Preparing request…")
        case .awaitingResponse:
            messages.append("Waiting for model…")
        case .streaming:
            break
        case .paused:
            messages.append("Streaming paused")
        case .completed, .failed, .idle:
            break
        }

        switch conversation.snapshot.reasoningPhase {
        case .drafting, .reasoning:
            messages.append("Thinking…")
        case .completed(let summary) where summary?.isEmpty == false:
            if let summary {
                messages.append("Reasoning summary: \(summary)")
            }
        case .failed(let reason):
            messages.append("Reasoning failed: \(reason ?? "Unknown error")")
        case .none, .completed:
            break
        }

        switch conversation.snapshot.toolCallPhase {
        case .running(let name, let callType):
            messages.append(toolLabel(prefix: "Running", name: name, callType: callType))
        case .awaitingOutput(let name, let callType):
            messages.append(toolLabel(prefix: "Awaiting tool output from", name: name, callType: callType))
        case .completed(let name, let callType):
            messages.append(toolLabel(prefix: "Tool completed", name: name, callType: callType))
        case .failed(let name, let callType, let reason):
            let base = toolLabel(prefix: "Tool failed", name: name, callType: callType)
            if let reason, !reason.isEmpty {
                messages.append("\(base): \(reason)")
            } else {
                messages.append(base)
            }
        case .none:
            break
        }

        switch conversation.snapshot.webSearchPhase {
        case .initiated(let query):
            if let query, !query.isEmpty {
                messages.append("Preparing web search for \(query)…")
            } else {
                messages.append("Preparing web search…")
            }
        case .searching:
            messages.append("Searching the web…")
        case .analyzing:
            messages.append("Analyzing search results…")
        case .failed(let reason):
            messages.append("Web search failed: \(reason ?? "Unknown error")")
        case .completed, .none:
            break
        }

        switch conversation.snapshot.fileSearchPhase {
        case .preparing:
            messages.append("Preparing file search…")
        case .searching:
            messages.append("Searching files…")
        case .failed(let reason):
            messages.append("File search failed: \(reason ?? "Unknown error")")
        case .completed, .none:
            break
        }

        return deduplicated(messages)
    }

    func toolLabel(prefix: String, name: String?, callType: String?) -> String {
        switch (name, callType) {
        case (let name?, let type?) where !name.isEmpty && !type.isEmpty:
            return "\(prefix) \(name) (\(type))"
        case (let name?, _) where !name.isEmpty:
            return "\(prefix) \(name)"
        case (_, let type?) where !type.isEmpty:
            return "\(prefix) \(type)"
        default:
            return "\(prefix) tool"
        }
    }

    func deduplicated(_ messages: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for message in messages where seen.insert(message).inserted {
            ordered.append(message)
        }
        return ordered
    }
}
