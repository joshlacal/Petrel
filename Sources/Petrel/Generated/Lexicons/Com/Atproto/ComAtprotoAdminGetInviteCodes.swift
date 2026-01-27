import Foundation

// lexicon: 1, id: com.atproto.admin.getInviteCodes

public enum ComAtprotoAdminGetInviteCodes {
    public static let typeIdentifier = "com.atproto.admin.getInviteCodes"
    public struct Parameters: Parametrizable {
        public let sort: String?
        public let limit: Int?
        public let cursor: String?

        public init(
            sort: String? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.sort = sort
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let codes: [ComAtprotoServerDefs.InviteCode]

        /// Standard public initializer
        public init(
            cursor: String? = nil,

            codes: [ComAtprotoServerDefs.InviteCode]

        ) {
            self.cursor = cursor

            self.codes = codes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            codes = try container.decode([ComAtprotoServerDefs.InviteCode].self, forKey: .codes)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(codes, forKey: .codes)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let codesValue = try codes.toCBORValue()
            map = map.adding(key: "codes", value: codesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case codes
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - getInviteCodes

    /// Get an admin view of invite codes.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getInviteCodes(input: ComAtprotoAdminGetInviteCodes.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminGetInviteCodes.Output?) {
        let endpoint = "com.atproto.admin.getInviteCodes"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.admin.getInviteCodes")
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
                let decodedData = try decoder.decode(ComAtprotoAdminGetInviteCodes.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.admin.getInviteCodes: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
