import Foundation

// lexicon: 1, id: com.atproto.server.revokeAppPassword

public enum ComAtprotoServerRevokeAppPassword {
    public static let typeIdentifier = "com.atproto.server.revokeAppPassword"
    public struct Input: ATProtocolCodable {
        public let name: String

        // Standard public initializer
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

        private enum CodingKeys: String, CodingKey {
            case name
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let nameValue = try name.toCBORValue()
            map = map.adding(key: "name", value: nameValue)

            return map
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

        let (_, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
