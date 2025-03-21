import Foundation

// lexicon: 1, id: com.atproto.identity.updateHandle

public enum ComAtprotoIdentityUpdateHandle {
    public static let typeIdentifier = "com.atproto.identity.updateHandle"
    public struct Input: ATProtocolCodable {
        public let handle: String

        // Standard public initializer
        public init(handle: String) {
            self.handle = handle
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    /// Updates the current account's handle. Verifies handle validity, and updates did:plc document if necessary. Implemented by PDS, and requires auth.
    func updateHandle(
        input: ComAtprotoIdentityUpdateHandle.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.identity.updateHandle"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
