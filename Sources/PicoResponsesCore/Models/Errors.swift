import Foundation

public enum PicoResponsesError: Error, Sendable {
    case invalidURL
    case requestEncodingFailed(underlying: Error)
    case responseDecodingFailed(underlying: Error)
    case httpError(statusCode: Int, data: Data?)
    case networkError(underlying: Error)
    case streamDecodingFailed(underlying: Error)
}
