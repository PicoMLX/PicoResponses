//
//  SwiftUIView.swift
//  PicoResponses
//
//  Created by Ronald Mannak on 10/5/25.
//

import SwiftUI

struct ComposeView: View {
    
    @Binding var text: String
    var isSending: Bool
    var onSend: () -> Void
    
    private let maxHeight: CGFloat = 160
    
    var body: some View {
        VStack(spacing: 6) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
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
                
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Message")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                    }
                    
                    TextEditor(text: $text)
                        .frame(minHeight: 34, maxHeight: maxHeight)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2))
                )
                
                Button {
                    onSend()
                } label: {
                    if isSending { ProgressView() } else { Image(systemName: "paperplane.fill") }
                }
                .keyboardShortcut(.return, modifiers: [.command]) // ⌘↩ to send
                .disabled(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }
}
