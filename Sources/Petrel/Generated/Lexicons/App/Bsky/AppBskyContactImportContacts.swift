import Foundation

// lexicon: 1, id: app.bsky.contact.importContacts

public enum AppBskyContactImportContacts {
    public static let typeIdentifier = "app.bsky.contact.importContacts"
    public struct Input: ATProtocolCodable {
        public let token: String
        public let contacts: [String]

        /// Standard public initializer
        public init(token: String, contacts: [String]) {
            self.token = token
            self.contacts = contacts
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            token = try container.decode(String.self, forKey: .token)
            contacts = try container.decode([String].self, forKey: .contacts)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(token, forKey: .token)
            try container.encode(contacts, forKey: .contacts)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let tokenValue = try token.toCBORValue()
            map = map.adding(key: "token", value: tokenValue)
            let contactsValue = try contacts.toCBORValue()
            map = map.adding(key: "contacts", value: contactsValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case token
            case contacts
        }
    }

    public struct Output: ATProtocolCodable {
        public let matchesAndContactIndexes: [AppBskyContactDefs.MatchAndContactIndex]

        /// Standard public initializer
        public init(
            matchesAndContactIndexes: [AppBskyContactDefs.MatchAndContactIndex]

        ) {
            self.matchesAndContactIndexes = matchesAndContactIndexes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            matchesAndContactIndexes = try container.decode([AppBskyContactDefs.MatchAndContactIndex].self, forKey: .matchesAndContactIndexes)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(matchesAndContactIndexes, forKey: .matchesAndContactIndexes)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let matchesAndContactIndexesValue = try matchesAndContactIndexes.toCBORValue()
            map = map.adding(key: "matchesAndContactIndexes", value: matchesAndContactIndexesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case matchesAndContactIndexes
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case invalidDid = "InvalidDid."
        case invalidContacts = "InvalidContacts."
        case tooManyContacts = "TooManyContacts."
        case invalidToken = "InvalidToken."
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
    // MARK: - importContacts

    /// Import contacts for securely matching with other users. This follows the protocol explained in https://docs.bsky.app/blog/contact-import-rfc. Requires authentication.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func importContacts(
        input: AppBskyContactImportContacts.Input

    ) async throws -> (responseCode: Int, data: AppBskyContactImportContacts.Output?) {
        let endpoint = "app.bsky.contact.importContacts"

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
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.contact.importContacts")
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
                let decodedData = try decoder.decode(AppBskyContactImportContacts.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.contact.importContacts: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
