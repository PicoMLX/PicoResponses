# PicoResponses Rules & Architecture

## Scope Overview
- Deliver a Swift package that fully covers the OpenAI Responses API v1 and Conversations API v1, including management endpoints (retrieve, list, cancel/delete) and conversation chaining via `previous_response_id`.
- Provide first-class streaming support (Server-Sent Events and chunked HTTP bodies) surfaced as `AsyncSequence`/`AsyncThrowingStream` types, with resumable or restartable flows.
- Offer a minimal-chat convenience layer for common “user ↔ assistant” exchanges while exposing lower-level primitives for advanced orchestration.
- Ensure parity between client (SwiftUI) and server (Hummingbird 2) use cases by reusing models and request/response builders.
- Do not over engineer or over-complicate things. Keep it simple and easy to read.

## Non-Goals (for v1)
- No UI asset library beyond reference SwiftUI views; consumer apps own final styling.
- No persistence layer for conversations or embeddings; provide protocols/hooks for apps to supply their own storage.
- No vendor abstraction beyond OpenAI; future providers require separate work.
- No automatic quota/backoff management for third-party rate limits—expose hooks so hosting apps can implement policies.

## Module Layout & Naming
| Module | Purpose | Dependencies | Notes |
| --- | --- | --- | --- |
| `PicoResponsesCore` | Networking clients, request builders, Codable models mirroring OpenAI schemas, streaming plumbing, tool/function call abstractions. | Foundation, Swift Concurrency, URLSession, optional `MultipartKit` for uploads. | Constrain public surface to `Sendable` and `@unchecked Sendable` only when justified. |
| `PicoResponsesConversation` | Conversation state manager, memory strategies, pagination helpers, history truncation policies. | `PicoResponsesCore` | Provides pluggable summarization/truncation strategies. |
| `PicoResponsesSwiftUI` | Observable view models, adapters for streaming updates, bindings to SwiftUI Observation framework. | `PicoResponsesCore`, `Observation` | Use Swift 6 `@Observable` and `@MainActor` isolates. |
| `PicoResponsesViews` | Reference SwiftUI views demonstrating conversation UIs, streaming indicators, tool invocation UI. | `PicoResponsesSwiftUI` | Keep opt-in; ship as examples, not mandated dependencies. |
| `PicoResponsesServer` | Hummingbird 2 helpers, request routing, middleware, and `ResponseCodable` conformances. | `PicoResponsesCore`, Hummingbird 2, MLX-Swift (optional) | All HTTP handlers must be `Sendable` and support cancellation. |

## API Coverage Requirements
- Mirror the OpenAI schemas from the linked docs, including all content blocks (text, image, audio, tool calls, tool outputs) and status transitions.
- Explicitly support `/v1/responses`, `/v1/conversations`, and `/v1/files` endpoints, including file upload and management flows.
- Decode and surface webhook event objects emitted when Responses run in `background` mode so server consumers can verify and react to lifecycle callbacks.
- Handcraft Codable request/response models for `/v1/responses`, `/v1/conversations`, and `/v1/files` based on the official documentation and the referenced Swift examples, ensuring we only model the fields we support while leaving room for forward-compatible extensions.
- Support parameter sets: model, input content, parallel tool choice, metadata, max tokens, temperature, top-p, `response_format`, `modalities`, `reasoning`, safety settings, `session` options, `webhook` registration, and `metadata` objects.
- Expose convenience builders for multi-part content (text + references, images, audio) and file uploads (`multipart/form-data`). Validate file size/content-type locally before upload.
- Implement pagination helpers for list endpoints with typed page tokens and limit validation.
- Surface webhook event models (per the provided link) for consumers to decode server-side.

## Streaming & Concurrency Guidelines
- Represent streaming responses as `AsyncThrowingStream<ResponseChunk, Error>` where `ResponseChunk` captures delta metadata, tool calls, and completion signals.
- Ensure all streaming code is cancellation-aware and closes streams on task cancellation or network failure.
- Centralize retry/backoff logic behind a `RetryPolicy` protocol supporting exponential backoff, jitter, and user-configurable limits.
- Adopt Swift 6 concurrency best practices: mark long-lived managers as `actor`s, define protocol requirements as `Sendable`, and use clock APIs for timeout management.

## Tool & Function Calling Contracts
- Provide a protocol (e.g., `ResponseTool`) that describes tool metadata, JSON schemas, and invocation entry points.
- Handle assistant tool call deltas incrementally, aggregating arguments until the call completes.
- Offer adapters for synchronous and asynchronous tool execution, with hooks to emit interim status back into the conversation stream.
- Warn consumers that tool invocation happens within their process; document security implications and recommend input validation.

## Configuration & Error Handling
- Centralize configuration in an immutable `ResponsesClient.Configuration` covering base URL, default model, timeouts (`Duration`), request modifiers, logging level, and retry policy.
- Emit typed errors (`ResponsesError`) categorizing transport, decoding, API, and tool failures, preserving server-provided error payloads.
- Provide middleware hooks for logging, metrics, redaction, and request mutation.
- Highlight that API keys must never be logged; redact sensitive headers in debug output.

## SwiftUI Integration
- Base observable models on the Observation framework (`@Observable`, `@State`, `@Bindable`), maintaining `@MainActor` isolation for UI-facing types.
- Structure streaming updates through `AsyncStream` bridging to `MainActor` to avoid cross-actor violations.
- Supply sample dependency injection (preview data, mock streaming sequences) for SwiftUI previews.

## Server Integration (Hummingbird 2)
- This target is for Hummingbird 2.0 projects that need OpenAI-compatibility to allow chat clients to connect to it using Responses and Coversations API
- Implement `ResponseCodable` extensions for the structs in the Core that the server will return to the client
- Include optional MLX-Swift helpers to map tool calls to local model inference, keeping MLX dependencies isolated behind feature flags.
- Document server deployment considerations: API key storage (environment/secret manager), rate limiting, webhook signature validation.

## Testing & Quality Gates
- Unit test Codable models against captured fixtures from the OpenAI docs (happy path and edge cases). Maintain fixtures in `Tests/Resources`.
- Add integration tests using `URLProtocol` stubs to simulate streaming, retries, and tool callback flows.
- Provide SwiftUI snapshot or preview tests for reference views where practical.
- Implement server-side tests with `HummingbirdXCT` to ensure routes and middleware behave under load and cancellation.
- Run `swift test --parallel` and SwiftLint/formatting (if adopted) in CI.

## Limitations, Risks & Warnings
- OpenAI API versions evolve quickly; segregate schema decoding into dedicated files for easier updates and guard unknown enum cases.
- Streaming endpoints may deliver non-UTF8 or binary payloads—validate and surface descriptive errors.
- Long-running streams can exhaust client memory if consumers buffer results; recommend incremental processing.
- Be explicit that responses can include sensitive content; provide moderation hooks but leave policy decisions to integrators.
- Webhooks must be verified against OpenAI signatures; failure to do so can expose systems to spoofed events.

## Open Questions / Follow-Ups
- Do we need built-in conversation persistence adapters (CloudKit, SQLite) for reference apps? -> No, but maybe keep the possibility open to add this in the future. Don't forget: do no overcomplicate the architecture
- Should we adopt `swift-openapi-generator` to ensure schema accuracy, or hand-roll Codable structures for flexibility? -> Decision: handcraft the models for the targeted endpoints to keep the surface lean and tailored to our streaming abstractions.
- Are we targeting additional platforms (visionOS, watchOS) that may impact SwiftUI packaging decisions? -> Support iOS, iPadOS, macOS and visionOS skip watchOS for now.
- Will we ship sample tooling (CLI) for quick testing? -> No, I will add an xcodeproj manually later
- Implementation-level helpers deferred to coding phase: SSE/event-stream parsing utilities, multipart convenience wrappers, retry/backoff configuration, and streaming resumption logic all need backlog coverage once core types are in place.

## References
- Responses API: https://platform.openai.com/docs/api-reference/responses
- Conversations API: https://platform.openai.com/docs/api-reference/conversations/create
- Streaming events: https://platform.openai.com/docs/api-reference/responses-streaming
- Webhook events: https://platform.openai.com/docs/api-reference/webhook-events
- Related projects for reference only:
  - https://github.com/MacPaw/OpenAI
  - https://github.com/m1guelpf/swift-openai-responses
