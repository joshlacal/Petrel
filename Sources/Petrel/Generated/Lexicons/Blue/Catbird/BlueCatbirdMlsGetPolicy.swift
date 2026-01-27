import Foundation

// lexicon: 1, id: blue.catbird.mls.getPolicy

public enum BlueCatbirdMlsGetPolicy {
    public static let typeIdentifier = "blue.catbird.mls.getPolicy"
    public struct Parameters: Parametrizable {
        public let convoId: String

        public init(
            convoId: String
        ) {
            self.convoId = convoId
        }
    }

    public struct Output: ATProtocolCodable {
        public let policy: BlueCatbirdMlsUpdatePolicy.PolicyView

        /// Standard public initializer
        public init(
            policy: BlueCatbirdMlsUpdatePolicy.PolicyView

        ) {
            self.policy = policy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            policy = try container.decode(BlueCatbirdMlsUpdatePolicy.PolicyView.self, forKey: .policy)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(policy, forKey: .policy)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let policyValue = try policy.toCBORValue()
            map = map.adding(key: "policy", value: policyValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case policy
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case convoNotFound = "ConvoNotFound.Conversation not found"
        case notMember = "NotMember.Caller is not a member of this conversation"
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getPolicy

    /// Retrieve conversation policy settings Query to fetch policy settings for a conversation. All members can view policy.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getPolicy(input: BlueCatbirdMlsGetPolicy.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetPolicy.Output?) {
        let endpoint = "blue.catbird.mls.getPolicy"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getPolicy")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetPolicy.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getPolicy: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
