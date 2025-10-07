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
    
    @State private var serverURL: URL?
    
    var body: some Scene {
        WindowGroup {
            if let serverURL {
                ConversationView(conversation: createConversation(from: serverURL))
            } else {
                SelectServerView(serverURL: $serverURL)
            }
        }
    }
    
    func createConversation(from url: URL) -> ConversationViewModel {
        print("running conversation")
        let config =  PicoResponsesConfiguration(apiKey: "", baseURL: url)
        let client = ResponsesClient(configuration: config)
        let service = LiveConversationService(client: client, requestBuilder: ConversationRequestBuilder(model: "gpt-4.1-mini"))
        return ConversationViewModel(service: service)
    }
}
