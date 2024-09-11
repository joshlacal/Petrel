import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.server.reserveSigningKey

public enum ComAtprotoServerReserveSigningKey {
    public static let typeIdentifier = "com.atproto.server.reserveSigningKey"
    public struct Input: ATProtocolCodable {
        public let did: String?

        // Standard public initializer
        public init(did: String? = nil) {
            self.did = did
        }
    }

    public struct Output: ATProtocolCodable {
        public let signingKey: String

        // Standard public initializer
        public init(
            signingKey: String
        ) {
            self.signingKey = signingKey
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Reserve a repo signing key, for use with account creation. Necessary so that a DID PLC update operation can be constructed during an account migraiton. Public and does not require auth; implemented by PDS. NOTE: this endpoint may change when full account migration is implemented.
    func reserveSigningKey(
        input: ComAtprotoServerReserveSigningKey.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ComAtprotoServerReserveSigningKey.Output?) {
        let endpoint = "/com.atproto.server.reserveSigningKey"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(ComAtprotoServerReserveSigningKey.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
