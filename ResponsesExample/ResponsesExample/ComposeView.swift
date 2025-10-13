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
                    .onKeyPress { press in
                        if press.key == .return {
                            if press.modifiers.isEmpty {
                                if !isSending && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    selection = nil
                                    onSend()
                                    return .handled
                                }
                            } else if press.modifiers == [.shift] {
                                insertNewlineAtCursor()
                                return .handled
                            }
                        }
                        return .ignored
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
        let selection = self.selection ?? TextSelection(insertionPoint: text.endIndex)
        if case let .selection(range) = selection.indices {
            text.replaceSubrange(range, with: "\n")
            if let index = text.index(range.lowerBound, offsetBy: 1, limitedBy: text.endIndex) {
                self.selection = TextSelection(insertionPoint: index)
            } else {
                self.selection = nil
            }
        }
    }
}
