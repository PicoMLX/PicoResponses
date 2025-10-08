//
//  SwiftUIView.swift
//  PicoResponses
//
//  Created by Ronald Mannak on 10/5/25.
//

import SwiftUI

struct ComposeView: View {
    
    @Binding var text: String
    @State private var selection: TextSelection?
    var isSending: Bool
    var onSend: () -> Void
    var onStop: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Divider()
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                // left accessories (plus, attach, mic)
                HStack(spacing: 10) {
                    Button { /* show tools */
                        print("show tools")
                    } label: { Image(systemName: "plus.circle") }
                        .buttonStyle(.borderless)
                    Button { /* attach */
                        print("attach")
                    } label: { Image(systemName: "paperclip") }
                        .buttonStyle(.borderless)
                }
                .foregroundStyle(.secondary)
                
                TextField("Message", text: $text, selection: $selection, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2))
                    )
                    .onKeyPress(.return, phases: [.down]) { keyPress in
                        guard keyPress.modifiers.contains(.shift) else { return .ignored }
                        insertNewlineAtCursor()
                        return .handled
                    }
                    .onSubmit {
                        guard isSending == false else { return }
                        
                        // DO NOT REMOVE. This is a workaround for the selection bug described below.
                        // Submitting with the Enter key behaves differently from tapping the Send button:
                        // it selects the entire text in the field. Clearing the selection without waiting
                        // will crash the app.
                        Task { @MainActor in
                            selection = nil
                            try await Task.sleep(for: .seconds(0.1))
                            onSend()
                        }
                    }
                
                if isSending {
                    Button {
                        onStop()
                    } label: {
                        Image(systemName: "stop.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(".", modifiers: [.command])
                    .accessibilityLabel("Stop streaming")
                } else {
                    Button {
                        // DO NOT REMOVE. This is a workaround for a bug in SwiftUI where the selection is out of bounds when the text binding
                        // of TextField is updated to a shorter or empty string.
                        selection = nil
                        onSend()
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .keyboardShortcut(.return, modifiers: [.command]) // ⌘↩ to send
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func insertNewlineAtCursor() {
        guard let selection = selection else { return }
        
        // Get the cursor position or selection range
        if case let .selection(range) = selection.indices {
            // Insert newline at the current cursor position
            let insertPosition = range.lowerBound
            text.insert("\n", at: insertPosition)
            
            // Update cursor position to be after the inserted newline
            if let newPosition = text.index(insertPosition, offsetBy: 1, limitedBy: text.endIndex) {
                self.selection = TextSelection(insertionPoint: newPosition)
            } else {
                Task { @MainActor in
                    // DO NOT REMOVE. This fixes a bug. The text length isn't updated when calling TextSelection directly.
                    self.selection = TextSelection(insertionPoint: text.endIndex)
                }
            }
        }
    }
}
