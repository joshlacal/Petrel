import Foundation

// lexicon: 1, id: com.atproto.server.revokeAppPassword

public enum ComAtprotoServerRevokeAppPassword {
    public static let typeIdentifier = "com.atproto.server.revokeAppPassword"
    public struct Input: ATProtocolCodable {
        public let name: String

        /// Standard public initializer
        public init(name: String) {
            self.name = name
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let nameValue = try name.toCBORValue()
            map = map.adding(key: "name", value: nameValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case name
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    // MARK: - revokeAppPassword

    /// Revoke an App Password by name.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func revokeAppPassword(
        input: ComAtprotoServerRevokeAppPassword.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.server.revokeAppPassword"

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
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.server.revokeAppPassword")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        return response.statusCode
    }
}
