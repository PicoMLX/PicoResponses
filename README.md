# PicoResponses

Handcrafted Swift clients and SwiftUI utilities for OpenAI-style Responses, Conversations, and Files endpoints. The package is split into two layers:

- `PicoResponsesCore` – Codable/Sendable models, JSONSchema helpers, structured errors, and an EventSource-powered HTTP client.
- `PicoResponsesSwiftUI` – streaming reducers, conversation state snapshots, and an `@Observable` view model for SwiftUI apps.

## Requirements

- Xcode 16 / Swift 6.2+
- iOS 17, macOS 14, tvOS 17, or visionOS 1 minimum (per `Package.swift`)

## Installation

1. In Xcode choose **File ▸ Add Packages… ▸ Add Local…**.
2. Select the root directory of this repository.
3. Add the products you need (typically both `PicoResponsesCore` and `PicoResponsesSwiftUI`).
4. Import the modules where you intend to use them:

```swift
import PicoResponsesCore
import PicoResponsesSwiftUI
```

## Configuring the Core Client

`PicoResponsesConfiguration` accepts an optional API key plus additional headers if your deployment requires them. Local servers that do not use bearer tokens can pass `nil`.

```swift
let configuration = PicoResponsesConfiguration(
    apiKey: Secrets.openAIKey,            // or nil for auth-less servers
    organizationId: nil,
    projectId: nil,
    baseURL: URL(string: "https://api.openai.com/v1")!,
    timeout: 120,
    streamingTimeout: 300                // optional override for SSE
)

let responsesClient = ResponsesClient(configuration: configuration)
```

### Building Conversation Services

`ConversationRequestBuilder` collects the model-level defaults. You can choose how much prior history to send using the `historyStrategy` and optionally supply a `previousResponseId` to let the API resume a prior response chain.

```swift
var builder = ConversationRequestBuilder(
    model: "gpt-4.1-mini",
    temperature: 0.7,
    frequencyPenalty: 0.2,
    presencePenalty: 0.1,
    maxOutputTokens: 512,
    historyStrategy: .latestMessage      // or .fullConversation
)

let liveService = LiveConversationService(
    client: responsesClient,
    requestBuilder: builder
)

let viewModel = ConversationViewModel(service: liveService)
```

## Conversation Flows

### Streaming Conversations

Call `submitPrompt()` from the SwiftUI layer. The view model sends only the most recent user message (per the `historyStrategy`) and includes `previous_response_id` automatically when available.

```swift
struct ChatView: View {
    @Bindable var conversation: ConversationViewModel

    var body: some View {
        VStack {
            List(conversation.snapshot.messages) { message in
                Text("\(message.role.rawValue.capitalized): \(message.text)")
            }

            if conversation.isStreaming {
                ProgressView("Streaming response…")
            }

            HStack {
                TextField("Ask anything", text: $conversation.draft, axis: .vertical)
                Button("Send", action: conversation.submitPrompt)
                    .disabled(conversation.isStreaming || conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
    }
}
```

### Non-Streaming (One-Shot) Requests

Invoke `submitOneShotPrompt()` to run the Responses API with `stream = false`. The view model reuses the same builder settings and still appends `previous_response_id` where appropriate.

```swift
Button("Send without streaming") {
    conversation.submitOneShotPrompt()
}
```

## Customising Sampling & History at Runtime

You can mutate the builder’s properties, create a new `LiveConversationService`, and swap the view model when users adjust settings such as model, temperature, penalties, and token limits.

```swift
func apply(settings: ConversationSettings) {
    var builder = ConversationRequestBuilder(
        model: settings.model,
        temperature: settings.temperature,
        topP: settings.topP,
        maxOutputTokens: settings.maxTokens,
        historyStrategy: settings.useFullHistory ? .fullConversation : .latestMessage
    )

    let service = LiveConversationService(client: responsesClient, requestBuilder: builder)
    conversation = ConversationViewModel(service: service)
}
```

### Manually Providing `previous_response_id`

If you maintain the transcript outside of `ConversationViewModel`, you can pass the identifier into `LiveConversationService` manually:

```swift
let stream = await liveService.startConversation(
    with: messages,
    previousResponseId: lastResponseId     // nil to start fresh
)
```

`ConversationStateSnapshot` exposes `lastResponseId` so you can persist it between runs.

## Files API & Multipart Uploads

`FilesClient` provides helpers for multi-part uploads via `sendMultipart` and raw downloads via `sendRawData`. Construct an array of `HTTPClient.MultipartPart` for each upload part, then call `filesClient.upload(...)`.

## Error Handling

- All networking errors are surfaced as `PicoResponsesError` with `LocalizedError` descriptions.
- Structured API errors decode the standard `{ "error": { "message": … } }` envelope, so `error.localizedDescription` returns the server’s message.
- Streaming failures retry once via EventSource and, on HTTP errors, re-fetch the body to decode the API payload.

## Testing & Previews

- `PreviewConversationService` feeds canned snapshots to SwiftUI previews.
- Reducer tests in `PicoResponsesSwiftUITests` demonstrate how to simulate SSE events for unit testing.

## License

PicoResponses is released under the MIT license. See `LICENSE` for details.
