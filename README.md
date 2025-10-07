# PicoResponses

Handcrafted Swift clients and SwiftUI utilities for the OpenAI Responses, Conversations, and Files APIs. The package is split into two layers:

- `PicoResponsesCore` – strongly typed request/response models plus HTTP and streaming clients built on EventSource.
- `PicoResponsesSwiftUI` – SwiftUI-friendly state types, mock services, and an `@Observable` conversation view model.

## Requirements

- Xcode 16 / Swift 6.2+
- iOS 17, macOS 14, tvOS 17, or visionOS 1 minimum deployment (per `Package.swift`)
- An OpenAI API key (stored securely, e.g. in the keychain or environment variables)

## Adding the Package to an App

1. In Xcode select **File ▸ Add Packages…** and choose **Add Local…**.
2. Select the root folder of this repository (`PicoResponses`).
3. Add the products you need to your target: typically both `PicoResponsesCore` and `PicoResponsesSwiftUI`.
4. Import the modules in your app files:

```swift
import PicoResponsesCore
import PicoResponsesSwiftUI
```

## Bootstrapping the Core Client

Create a configuration with your credentials, then build the `ResponsesClient` and SwiftUI service objects you plan to reuse across views.

```swift
// AppDelegate / SceneDelegate or a dedicated dependency container
let configuration = PicoResponsesConfiguration(
    apiKey: Secrets.openAIKey,
    organizationId: nil,
    projectId: nil,
    streamingTimeout: 300 // optional override for SSE connections
)

let responsesClient = ResponsesClient(configuration: configuration)
let requestBuilder = ConversationRequestBuilder(model: "gpt-4.1-mini")
let liveService = LiveConversationService(client: responsesClient, requestBuilder: requestBuilder)
```

Pass the service (or a `ConversationViewModel`) into your SwiftUI hierarchy using dependency injection, an environment object, or a simple initializer.

## Example 1 – Basic Chat View

```swift
import SwiftUI
import PicoResponsesCore
import PicoResponsesSwiftUI

struct ChatView: View {
    @Bindable var viewModel: ConversationViewModel

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                ForEach(viewModel.snapshot.messages) { message in
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

            if let error = viewModel.lastObservedError {
                Text(error)
                    .foregroundStyle(.red)
            }

            HStack {
                TextField("Ask anything…", text: $viewModel.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                Button("Send") {
                    viewModel.submitPrompt()
                }
                .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
            }
        }
        .padding()
        .animation(.default, value: viewModel.snapshot.messages)
    }
}

@main
struct ResponsesExampleApp: App {
    private let client: ResponsesClient
    private let service: LiveConversationService
    @State private var viewModel: ConversationViewModel

    init() {
        let configuration = PicoResponsesConfiguration(apiKey: Secrets.openAIKey)
        let client = ResponsesClient(configuration: configuration)
        let builder = ConversationRequestBuilder(model: "gpt-4.1-mini")
        let service = LiveConversationService(client: client, requestBuilder: builder)

        self.client = client
        self.service = service
        _viewModel = State(initialValue: ConversationViewModel(service: service))
    }

    var body: some Scene {
        WindowGroup {
            ChatView(viewModel: viewModel)
        }
    }
}
```

The view reads all UI state from the `ConversationViewModel.snapshot`, while the app builds and injects the live service once at launch.

## Example 2 – Adjustable Conversation Settings

The next snippet shows a lightweight control panel that lets the user tweak model, temperature, and max tokens. When the settings change we rebuild the `LiveConversationService` and `ConversationViewModel`, effectively starting a fresh conversation with the new configuration.

```swift
struct ConversationSettings: Equatable {
    var model: String = "gpt-4.1-mini"
    var temperature: Double = 0.7
    var maxOutputTokens: Int = 512

    func makeBuilder() -> ConversationRequestBuilder {
        ConversationRequestBuilder(
            model: model,
            temperature: temperature,
            maxOutputTokens: maxOutputTokens
        )
    }
}

struct ConfigurableChatView: View {
    private let client: ResponsesClient
    @State private var settings = ConversationSettings()
    @State private var viewModel: ConversationViewModel

    init(client: ResponsesClient) {
        self.client = client
        let defaultSettings = ConversationSettings()
        let builder = defaultSettings.makeBuilder()
        let service = LiveConversationService(client: client, requestBuilder: builder)
        _viewModel = State(initialValue: ConversationViewModel(service: service))
        _settings = State(initialValue: defaultSettings)
    }

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("Model") {
                    TextField("Model", text: $settings.model)
                }

                Section("Sampling") {
                    HStack {
                        Text("Temperature")
                        Slider(value: $settings.temperature, in: 0...1)
                        Text(settings.temperature.formatted(.number.precision(.fractionLength(2))))
                    }
                }

                Section("Limits") {
                    Stepper(value: $settings.maxOutputTokens, in: 128...4096, step: 64) {
                        Text("Max output tokens: \(settings.maxOutputTokens)")
                    }
                }

                Button("Apply Settings") {
                    let builder = settings.makeBuilder()
                    let service = LiveConversationService(client: client, requestBuilder: builder)
                    viewModel = ConversationViewModel(service: service)
                }
            }
            .frame(maxHeight: 320)

            ChatView(viewModel: viewModel)
        }
        .padding()
    }
}
```

> **Note:** Rebuilding the view model resets the transcript. For more advanced scenarios you can store the transcript externally, or implement a custom `ConversationService` that accepts live configuration updates without recreating the view model.

## Mocking & Testing

- Use `PreviewConversationService` to render SwiftUI previews without hitting the network.
- The `PicoResponsesSwiftUITests` target contains reducer tests showing how to drive the state machine with mocked streaming events.

## License

This project is provided under the MIT license. See `LICENSE` for details.
