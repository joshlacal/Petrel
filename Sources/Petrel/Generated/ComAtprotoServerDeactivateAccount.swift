import Foundation

// lexicon: 1, id: com.atproto.server.deactivateAccount

public enum ComAtprotoServerDeactivateAccount {
    public static let typeIdentifier = "com.atproto.server.deactivateAccount"
    public struct Input: ATProtocolCodable {
        public let deleteAfter: ATProtocolDate?

        // Standard public initializer
        public init(deleteAfter: ATProtocolDate? = nil) {
            self.deleteAfter = deleteAfter
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            deleteAfter = try container.decodeIfPresent(ATProtocolDate.self, forKey: .deleteAfter)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if let value = deleteAfter {
                try container.encode(value, forKey: .deleteAfter)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case deleteAfter
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
