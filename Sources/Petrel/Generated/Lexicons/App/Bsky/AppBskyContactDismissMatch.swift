import Foundation

// lexicon: 1, id: app.bsky.contact.dismissMatch

public enum AppBskyContactDismissMatch {
    public static let typeIdentifier = "app.bsky.contact.dismissMatch"
    public struct Input: ATProtocolCodable {
        public let subject: DID

        /// Standard public initializer
        public init(subject: DID) {
            self.subject = subject
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            subject = try container.decode(DID.self, forKey: .subject)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(subject, forKey: .subject)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case subject
        }
    }

    public struct Output: ATProtocolCodable {
        // Empty output - no properties (response is {})

        /// Standard public initializer
        public init(
        ) {}

        public init(from decoder: Decoder) throws {
            // Empty output - just validate it's an object by trying to get any container
            _ = try decoder.singleValueContainer()
        }

        public func encode(to encoder: Encoder) throws {
            // Empty output - encode empty object
            _ = encoder.singleValueContainer()
        }

        public func toCBORValue() throws -> Any {
            // Empty output - return empty CBOR map
            return OrderedCBORMap()
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case invalidDid = "InvalidDid."
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
    // MARK: - dismissMatch

    /// Removes a match that was found via contact import. It shouldn't appear again if the same contact is re-imported. Requires authentication.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func dismissMatch(
        input: AppBskyContactDismissMatch.Input

    ) async throws -> (responseCode: Int, data: AppBskyContactDismissMatch.Output?) {
        let endpoint = "app.bsky.contact.dismissMatch"

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
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.contact.dismissMatch")
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
                let decodedData = try decoder.decode(AppBskyContactDismissMatch.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.contact.dismissMatch: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
