import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.server.deactivateAccount

public enum ComAtprotoServerDeactivateAccount {
    public static let typeIdentifier = "com.atproto.server.deactivateAccount"
    public struct Input: ATProtocolCodable {
        public let deleteAfter: ATProtocolDate?

        // Standard public initializer
        public init(deleteAfter: ATProtocolDate? = nil) {
            self.deleteAfter = deleteAfter
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Deactivates a currently active account. Stops serving of repo, and future writes to repo until reactivated. Used to finalize account migration with the old host after the account has been activated on the new host.
    func deactivateAccount(
        input: ComAtprotoServerDeactivateAccount.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.server.deactivateAccount"

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
