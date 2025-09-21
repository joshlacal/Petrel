import Foundation

// lexicon: 1, id: com.atproto.identity.refreshIdentity

public enum ComAtprotoIdentityRefreshIdentity {
    public static let typeIdentifier = "com.atproto.identity.refreshIdentity"
    public struct Input: ATProtocolCodable {
        public let identifier: ATIdentifier

        // Standard public initializer
        public init(identifier: ATIdentifier) {
            self.identifier = identifier
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            identifier = try container.decode(ATIdentifier.self, forKey: .identifier)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(identifier, forKey: .identifier)
        }

        private enum CodingKeys: String, CodingKey {
            case identifier
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let identifierValue = try identifier.toCBORValue()
            map = map.adding(key: "identifier", value: identifierValue)

            return map
        }
    }

    public typealias Output = ComAtprotoIdentityDefs.IdentityInfo

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case handleNotFound = "HandleNotFound.The resolution process confirmed that the handle does not resolve to any DID."
        case didNotFound = "DidNotFound.The DID resolution process confirmed that there is no current DID."
        case didDeactivated = "DidDeactivated.The DID previously existed, but has been deactivated."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    // MARK: - refreshIdentity

    /// Request that the server re-resolve an identity (DID and handle). The server may ignore this request, or require authentication, depending on the role, implementation, and policy of the server.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func refreshIdentity(
        input: ComAtprotoIdentityRefreshIdentity.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoIdentityRefreshIdentity.Output?) {
        let endpoint = "com.atproto.identity.refreshIdentity"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
                let decodedData = try decoder.decode(ComAtprotoIdentityRefreshIdentity.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.identity.refreshIdentity: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
