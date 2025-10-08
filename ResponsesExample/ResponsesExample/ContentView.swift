//
//  ContentView.swift
//  ResponsesExample
//
//  Created by Ronald Mannak on 10/8/25.
//

import SwiftUI
import PicoResponsesCore
import PicoResponsesSwiftUI

struct ContentView: View {

    let service: LiveConversationService
    var onSelectServer: () -> Void
    @State var conversations: [ConversationViewModel] = []
    @State private var selectedConversation: ConversationViewModel?
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List {
                ForEach(conversations) { conversation in
                    NavigationLink {
                        ConversationView(conversation: conversation)
                    } label: {
                        Text(conversation.snapshot.topic ?? "New Conversation")
                    }
                }
                .onDelete(perform: deleteItems)
            }
        } detail: {
            ConversationView(conversation: selectedConversation ?? ConversationViewModel(service: service))
        }
        .toolbar {
            ToolbarItem {
                Button(action: newConversation) {
                    Label("New Conversation", systemImage: "square.and.pencil")
                }
            }
            ToolbarItem {
                Button(action: onSelectServer) {
                    Label("Select Provider", systemImage: "arrow.triangle.swap") //"globe.badge.chevron.backward")
                }
            }
        }
    }
    
    private func newConversation() {
        selectedConversation = nil
    }
    
    private func deleteItems(at offsets: IndexSet) {
        conversations.remove(atOffsets: offsets)
    }
    
    private func storeConversation(_ conversation: ConversationViewModel) {
        conversations.append(conversation)
        conversations.sort { $0.snapshot.createdAt > $1.snapshot.createdAt }
    }
}
