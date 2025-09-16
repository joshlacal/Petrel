import Foundation

// lexicon: 1, id: com.atproto.server.getServiceAuth

public enum ComAtprotoServerGetServiceAuth {
    public static let typeIdentifier = "com.atproto.server.getServiceAuth"
    public struct Parameters: Parametrizable {
        public let aud: DID
        public let exp: Int?
        public let lxm: NSID?

        public init(
            aud: DID,
            exp: Int? = nil,
            lxm: NSID? = nil
        ) {
            self.aud = aud
            self.exp = exp
            self.lxm = lxm
        }
    }

    public struct Output: ATProtocolCodable {
        public let token: String

        // Standard public initializer
        public init(
            token: String

        ) {
            self.token = token
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            token = try container.decode(String.self, forKey: .token)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(token, forKey: .token)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let tokenValue = try token.toCBORValue()
            map = map.adding(key: "token", value: tokenValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case token
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case badExpiration = "BadExpiration.Indicates that the requested expiration date is not a valid. May be in the past or may be reliant on the requested scopes."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    // MARK: - getServiceAuth

    /// Get a signed token on behalf of the requesting DID for the requested service.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getServiceAuth(input: ComAtprotoServerGetServiceAuth.Parameters) async throws -> (responseCode: Int, data: ComAtprotoServerGetServiceAuth.Output?) {
        let endpoint = "com.atproto.server.getServiceAuth"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoServerGetServiceAuth.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.server.getServiceAuth: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
