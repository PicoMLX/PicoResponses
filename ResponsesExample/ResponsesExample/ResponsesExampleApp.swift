//
//  ResponsesExampleApp.swift
//  ResponsesExample
//
//  Created by Ronald Mannak on 10/5/25.
//

import SwiftUI
import PicoResponsesCore
import PicoResponsesSwiftUI

@main
struct ResponsesExampleApp: App {
    
    /// Connected server tuple: serverURL (e.g.`https://api.openai.com/v1`), apiKey (e.g.`sk-...`), and models (e.g.`[gpt-5-nano]`)
    @State private var server: (URL, String?, [String])?
    
    var body: some Scene {
        WindowGroup {
            if let server {
                ContentView(service: createConversationService(server: server))
//                ConversationView(conversation: createConversation(server: server))
            } else {
                SelectServerView(server: $server)
            }
        }
    }
    
    private func createConversation(server: (URL, String?, [String])) -> ConversationViewModel {
        let config =  PicoResponsesConfiguration(
            apiKey: server.1,
            baseURL: server.0
        )
        let client = ResponsesClient(configuration: config)
        let service = LiveConversationService(client: client, requestBuilder: ConversationRequestBuilder(model: server.2.first ?? "gpt-5-nano"))
        return ConversationViewModel(service: service)
    }
    
    private func createConversationService(server: (URL, String?, [String])) -> LiveConversationService {
        print("running conversation")
        let config =  PicoResponsesConfiguration(
            apiKey: server.1,
            baseURL: server.0
        )
        let client = ResponsesClient(configuration: config)
        return LiveConversationService(client: client, requestBuilder: ConversationRequestBuilder(model: server.2.first ?? "gpt-5-nano"))
    }
}
