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
    
    @State private var height: CGFloat = 34
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
                
                GrowingTextView(text: $text, minHeight: 34, maxHeight: maxHeight)
                    .overlay(
                        Group {
                            if text.isEmpty {
                                Text("Message").foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    )
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

/// NSTextView-backed growing field for macOS
struct GrowingTextView: NSViewRepresentable {
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let tv = scroll.documentView as! NSTextView
        tv.isRichText = false
        tv.font = .systemFont(ofSize: NSFont.systemFontSize)
        tv.textContainerInset = NSSize(width: 6, height: 6)
        tv.delegate = context.coordinator
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.string = text
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        return scroll
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let tv = nsView.documentView as! NSTextView
        if tv.string != text { tv.string = text }
        // cap height
        if let container = tv.textContainer, let lm = tv.layoutManager {
            lm.ensureLayout(for: container)
            let size = lm.usedRect(for: container).size
            let h = min(max(size.height + 12, minHeight), maxHeight)
            nsView.heightAnchor.constraint(equalToConstant: h).isActive = true
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GrowingTextView
        init(_ parent: GrowingTextView) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            let tv = notification.object as! NSTextView
            parent.text = tv.string
        }
    }
}
