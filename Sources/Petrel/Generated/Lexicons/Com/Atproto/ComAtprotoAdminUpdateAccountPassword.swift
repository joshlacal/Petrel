import Foundation

// lexicon: 1, id: com.atproto.admin.updateAccountPassword

public enum ComAtprotoAdminUpdateAccountPassword {
    public static let typeIdentifier = "com.atproto.admin.updateAccountPassword"
    public struct Input: ATProtocolCodable {
        public let did: DID
        public let password: String

        /// Standard public initializer
        public init(did: DID, password: String) {
            self.did = did
            self.password = password
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            did = try container.decode(DID.self, forKey: .did)

            password = try container.decode(String.self, forKey: .password)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(did, forKey: .did)

            try container.encode(password, forKey: .password)
        }

        private enum CodingKeys: String, CodingKey {
            case did
            case password
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)

            let passwordValue = try password.toCBORValue()
            map = map.adding(key: "password", value: passwordValue)

            return map
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - updateAccountPassword

    /// Update the password for a user account as an administrator.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func updateAccountPassword(
        input: ComAtprotoAdminUpdateAccountPassword.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.updateAccountPassword"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.admin.updateAccountPassword")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        return response.statusCode
    }
}
