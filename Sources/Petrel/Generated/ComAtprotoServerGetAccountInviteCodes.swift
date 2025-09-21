import Foundation

// lexicon: 1, id: com.atproto.server.getAccountInviteCodes

public enum ComAtprotoServerGetAccountInviteCodes {
    public static let typeIdentifier = "com.atproto.server.getAccountInviteCodes"
    public struct Parameters: Parametrizable {
        public let includeUsed: Bool?
        public let createAvailable: Bool?

        public init(
            includeUsed: Bool? = nil,
            createAvailable: Bool? = nil
        ) {
            self.includeUsed = includeUsed
            self.createAvailable = createAvailable
        }
    }

    public struct Output: ATProtocolCodable {
        public let codes: [ComAtprotoServerDefs.InviteCode]

        // Standard public initializer
        public init(
            codes: [ComAtprotoServerDefs.InviteCode]

        ) {
            self.codes = codes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            codes = try container.decode([ComAtprotoServerDefs.InviteCode].self, forKey: .codes)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(codes, forKey: .codes)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let codesValue = try codes.toCBORValue()
            map = map.adding(key: "codes", value: codesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case codes
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case duplicateCreate = "DuplicateCreate."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    // MARK: - getAccountInviteCodes

    /// Get all invite codes for the current account. Requires auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getAccountInviteCodes(input: ComAtprotoServerGetAccountInviteCodes.Parameters) async throws -> (responseCode: Int, data: ComAtprotoServerGetAccountInviteCodes.Output?) {
        let endpoint = "com.atproto.server.getAccountInviteCodes"

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
                let decodedData = try decoder.decode(ComAtprotoServerGetAccountInviteCodes.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.server.getAccountInviteCodes: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
