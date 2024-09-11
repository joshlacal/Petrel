import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.server.getServiceAuth

public enum ComAtprotoServerGetServiceAuth {
    public static let typeIdentifier = "com.atproto.server.getServiceAuth"
    public struct Parameters: Parametrizable {
        public let aud: String
        public let exp: Int?
        public let lxm: String?

        public init(
            aud: String,
            exp: Int? = nil,
            lxm: String? = nil
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
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case badExpiration = "BadExpiration.Indicates that the requested expiration date is not a valid. May be in the past or may be reliant on the requested scopes."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Get a signed token on behalf of the requesting DID for the requested service.
    func getServiceAuth(input: ComAtprotoServerGetServiceAuth.Parameters) async throws -> (responseCode: Int, data: ComAtprotoServerGetServiceAuth.Output?) {
        let endpoint = "/com.atproto.server.getServiceAuth"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoServerGetServiceAuth.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
