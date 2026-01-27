import Foundation

// lexicon: 1, id: app.bsky.contact.verifyPhone

public enum AppBskyContactVerifyPhone {
    public static let typeIdentifier = "app.bsky.contact.verifyPhone"
    public struct Input: ATProtocolCodable {
        public let phone: String
        public let code: String

        /// Standard public initializer
        public init(phone: String, code: String) {
            self.phone = phone
            self.code = code
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            phone = try container.decode(String.self, forKey: .phone)

            code = try container.decode(String.self, forKey: .code)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(phone, forKey: .phone)

            try container.encode(code, forKey: .code)
        }

        private enum CodingKeys: String, CodingKey {
            case phone
            case code
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let phoneValue = try phone.toCBORValue()
            map = map.adding(key: "phone", value: phoneValue)

            let codeValue = try code.toCBORValue()
            map = map.adding(key: "code", value: codeValue)

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let token: String

        /// Standard public initializer
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

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case rateLimitExceeded = "RateLimitExceeded."
        case invalidDid = "InvalidDid."
        case invalidPhone = "InvalidPhone."
        case invalidCode = "InvalidCode."
        case internalError = "InternalError."
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

public extension ATProtoClient.App.Bsky.Contact {
    // MARK: - verifyPhone

    /// Verifies control over a phone number with a code received via SMS and starts a contact import session. Requires authentication.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func verifyPhone(
        input: AppBskyContactVerifyPhone.Input

    ) async throws -> (responseCode: Int, data: AppBskyContactVerifyPhone.Output?) {
        let endpoint = "app.bsky.contact.verifyPhone"

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

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.contact.verifyPhone")
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
                let decodedData = try decoder.decode(AppBskyContactVerifyPhone.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.contact.verifyPhone: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
