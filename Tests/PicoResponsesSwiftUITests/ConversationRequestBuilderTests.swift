import XCTest
@testable import PicoResponsesSwiftUI

final class ConversationRequestBuilderTests: XCTestCase {
    func testBuilderAppliesTemperatureAndPenalties() {
        var builder = ConversationRequestBuilder(
            model: "gpt-4.1-mini",
            temperature: 0.6,
            topP: 0.9,
            frequencyPenalty: 0.2,
            presencePenalty: 0.1,
            maxOutputTokens: 512
        )
        builder.instructions = "You are a helpful assistant."

        let message = ConversationMessage(role: .user, text: "Hello")
        let request = builder.makeRequest(from: [message])

        XCTAssertEqual(request.model, "gpt-4.1-mini")
        XCTAssertEqual(request.temperature, 0.6)
        XCTAssertEqual(request.topP, 0.9)
        XCTAssertEqual(request.frequencyPenalty, 0.2)
        XCTAssertEqual(request.presencePenalty, 0.1)
        XCTAssertEqual(request.maxOutputTokens, 512)
        XCTAssertEqual(request.instructions, "You are a helpful assistant.")
    }
}
