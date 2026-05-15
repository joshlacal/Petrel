import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.reissueWelcomeRespond


public struct BlueCatbirdMlsChatReissueWelcomeRespond {

    public static let typeIdentifier = "blue.catbird.mlsChat.reissueWelcomeRespond"
public struct Input: ATProtocolCodable {
        public let requestId: String
        public let welcomeBlob: Bytes
        public let keyPackageHash: String?

        /// Standard public initializer
        public init(requestId: String, welcomeBlob: Bytes, keyPackageHash: String? = nil) {
            self.requestId = requestId
            self.welcomeBlob = welcomeBlob
            self.keyPackageHash = keyPackageHash
        }


        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.requestId = try container.decode(String.self, forKey: .requestId)
            self.welcomeBlob = try container.decode(Bytes.self, forKey: .welcomeBlob)
            self.keyPackageHash = try container.decodeIfPresent(String.self, forKey: .keyPackageHash)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(requestId, forKey: .requestId)
            try container.encode(welcomeBlob, forKey: .welcomeBlob)
            try container.encodeIfPresent(keyPackageHash, forKey: .keyPackageHash)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let requestIdValue = try requestId.toCBORValue()
            map = map.adding(key: "requestId", value: requestIdValue)
            let welcomeBlobValue = try welcomeBlob.toCBORValue()
            map = map.adding(key: "welcomeBlob", value: welcomeBlobValue)
            if let value = keyPackageHash {
                let keyPackageHashValue = try value.toCBORValue()
                map = map.adding(key: "keyPackageHash", value: keyPackageHashValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case requestId
            case welcomeBlob
            case keyPackageHash
        }
    }

public struct Output: ATProtocolCodable {


        public let stored: Bool

        public let requestId: String

        public let welcomeBlobId: String

        public let respondedAt: ATProtocolDate



        // Standard public initializer
        public init(


            stored: Bool,

            requestId: String,

            welcomeBlobId: String,

            respondedAt: ATProtocolDate


        ) {


            self.stored = stored

            self.requestId = requestId

            self.welcomeBlobId = welcomeBlobId

            self.respondedAt = respondedAt


        }

        public init(from decoder: Decoder) throws {

            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.stored = try container.decode(Bool.self, forKey: .stored)


            self.requestId = try container.decode(String.self, forKey: .requestId)


            self.welcomeBlobId = try container.decode(String.self, forKey: .welcomeBlobId)


            self.respondedAt = try container.decode(ATProtocolDate.self, forKey: .respondedAt)


        }

        public func encode(to encoder: Encoder) throws {

            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(stored, forKey: .stored)


            try container.encode(requestId, forKey: .requestId)


            try container.encode(welcomeBlobId, forKey: .welcomeBlobId)


            try container.encode(respondedAt, forKey: .respondedAt)


        }

        public func toCBORValue() throws -> Any {

            var map = OrderedCBORMap()



            let storedValue = try stored.toCBORValue()
            map = map.adding(key: "stored", value: storedValue)



            let requestIdValue = try requestId.toCBORValue()
            map = map.adding(key: "requestId", value: requestIdValue)



            let welcomeBlobIdValue = try welcomeBlobId.toCBORValue()
            map = map.adding(key: "welcomeBlobId", value: welcomeBlobIdValue)



            let respondedAtValue = try respondedAt.toCBORValue()
            map = map.adding(key: "respondedAt", value: respondedAtValue)



            return map

        }


        private enum CodingKeys: String, CodingKey {
            case stored
            case requestId
            case welcomeBlobId
            case respondedAt
        }

    }

public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case requestNotFound = "RequestNotFound.No pending unanswered reissue request exists for requestId."
                case unauthorized = "Unauthorized.Caller is not an active admin/inviter for the request conversation."
                case invalidWelcome = "InvalidWelcome.Welcome bytes are missing or invalid."
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}

extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - reissueWelcomeRespond

    /// Inviter/admin response to a pending reissueWelcome request. Stores a fresh MLS Welcome for the recipient device and marks the reissue request as answered.
    ///
    /// - Parameter input: The input parameters for the request

    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func reissueWelcomeRespond(

        input: BlueCatbirdMlsChatReissueWelcomeRespond.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatReissueWelcomeRespond.Output?) {
        let endpoint = "blue.catbird.mlsChat.reissueWelcomeRespond"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"



        headers["Accept"] = "application/json"



        let requestData: Data? = try JSONEncoder().encode(input)


        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.reissueWelcomeRespond")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode


        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled by the caller via the status code.
        if (200...299).contains(responseCode) {

            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }


            do {

                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(BlueCatbirdMlsChatReissueWelcomeRespond.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.reissueWelcomeRespond: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }

    }

}
