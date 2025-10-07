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
                }
            }
            
            // MARK: - Compose bar
            
            ComposeView(text: $conversation.draft, isSending: conversation.isStreaming) {
                conversation.submitPrompt()
                print("hit send")
            }
        }
    }
}
