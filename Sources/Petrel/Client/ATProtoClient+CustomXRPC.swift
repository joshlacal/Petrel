import Foundation

public extension ATProtoClient {
  /// Performs a custom XRPC procedure call (POST) for endpoints not in the generated client.
  ///
  /// Handles service DID routing, authentication, and JSON encoding/decoding.
  /// The caller must first configure the service DID for the endpoint's namespace
  /// via ``setServiceDID(_:for:)``.
  ///
  /// - Parameters:
  ///   - endpoint: The XRPC method identifier (e.g., "blue.catbird.bskychat.pushHeartbeat").
  ///   - input: An optional Encodable input body. Pass `nil` for procedures with no input.
  /// - Returns: A tuple of the HTTP response code and the raw response `Data`.
  func performCustomXRPCProcedure<Input: Encodable & Sendable>(
    endpoint: String,
    input: Input?
  ) async throws -> (responseCode: Int, data: Data) {
    var headers: [String: String] = [:]
    headers["Content-Type"] = "application/json"
    headers["Accept"] = "application/json"

    let requestData: Data? = if let input {
      try JSONEncoder().encode(input)
    } else {
      nil
    }

    let urlRequest = try await app.networkService.createURLRequest(
      endpoint: endpoint,
      method: "POST",
      headers: headers,
      body: requestData,
      queryItems: nil
    )

    let serviceDID = await app.networkService.getServiceDID(for: endpoint)
    let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
    let (responseData, response) = try await app.networkService.performRequest(
      urlRequest,
      skipTokenRefresh: false,
      additionalHeaders: proxyHeaders
    )

    return (responseCode: response.statusCode, data: responseData)
  }

  /// Performs a custom XRPC procedure call (POST) with no input body.
  ///
  /// Convenience overload for procedures that take no input.
  ///
  /// - Parameter endpoint: The XRPC method identifier.
  /// - Returns: A tuple of the HTTP response code and the raw response `Data`.
  func performCustomXRPCProcedure(
    endpoint: String
  ) async throws -> (responseCode: Int, data: Data) {
    try await performCustomXRPCProcedure(
      endpoint: endpoint,
      input: nil as [String: String]?
    )
  }
}
