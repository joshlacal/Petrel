import HTTPTypes
import Hummingbird

extension HTTPField.Name {
  public static let dpop = Self("DPoP")!
  public static let dpopNonce = Self("DPoP-Nonce")!
}

/// OAuth-style request error. The route layer converts these into JSON
/// `{"error": ..., "error_description": ...}` responses.
public struct CABRequestError: Error, Sendable, Equatable {
  public let status: Int
  public let error: String
  public let description: String

  public static func invalidDPoPProof(_ description: String) -> CABRequestError {
    CABRequestError(status: 400, error: "invalid_dpop_proof", description: description)
  }

  public static func invalidRequest(_ description: String) -> CABRequestError {
    CABRequestError(status: 400, error: "invalid_request", description: description)
  }

  public static func useDPoPNonce() -> CABRequestError {
    CABRequestError(
      status: 400, error: "use_dpop_nonce",
      description: "A DPoP nonce is required; retry with the DPoP-Nonce header value"
    )
  }

  public static func accessDenied(_ description: String) -> CABRequestError {
    CABRequestError(status: 403, error: "access_denied", description: description)
  }

  public static func rateLimited() -> CABRequestError {
    CABRequestError(status: 429, error: "rate_limited", description: "Too many requests")
  }
}
