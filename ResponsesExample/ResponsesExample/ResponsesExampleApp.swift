//
//  ResponsesExampleApp.swift
//  ResponsesExample
//
//  Created by Ronald Mannak on 10/5/25.
//

import SwiftUI

@main
struct ResponsesExampleApp: App {
    
    @State private var serverURL: String?
    
    var body: some Scene {
        WindowGroup {
            if let serverURL {
                ContentView()
            } else {
                ConnectServerView(serverURL: $serverURL)
            }
        }
    }
}

/*
Add the local PicoResponses package to the example project (File ▸ Add
   Packages…, Add Local…, select the repo root) and import both
   PicoResponsesCore and PicoResponsesSwiftUI in the app target. In
   ResponsesExampleApp, read your API key securely, build let config =
   PicoResponsesConfiguration(apiKey:…, streamingTimeout:…), then create let
   client = ResponsesClient(configuration: config) alongside let service =
   LiveConversationService(client: client, requestBuilder:
   ConversationRequestBuilder(model: "gpt-4.1-mini")). Hold the view model
   via @State private var viewModel = ConversationViewModel(service: service)
    (or inject it from a higher-level container) and pass it into
   ChatView(viewModel:). Inside ChatView, mark the parameter @Bindable var
   viewModel, render viewModel.snapshot.messages, and trigger await
   viewModel.submitPrompt() from UI actions while also reading phases like
   viewModel.snapshot.responsePhase for status indicators.
*/
