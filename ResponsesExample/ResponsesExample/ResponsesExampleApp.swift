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
    
    @State private var server: (URL, String?)? //= URL(string: "https://api.openai.com/v1")
    
    var body: some Scene {
        WindowGroup {
            if let server {
                ConversationView(conversation: createConversation(server: server))
            } else {
                SelectServerView(server: $server)
            }
        }
    }
    
    private func createConversation(server: (URL, String?)) -> ConversationViewModel {
        print("running conversation")
        let config =  PicoResponsesConfiguration(
            apiKey: server.1,
            baseURL: server.0
        )
        let client = ResponsesClient(configuration: config)
        let service = LiveConversationService(client: client, requestBuilder: ConversationRequestBuilder(model: "gpt-5-nano"))
        return ConversationViewModel(service: service)
    }
}
