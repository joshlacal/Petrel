import Foundation

// lexicon: 1, id: chat.bsky.group.getJoinLinkPreview

public enum ChatBskyGroupGetJoinLinkPreview {
    public static let typeIdentifier = "chat.bsky.group.getJoinLinkPreview"
    public struct Parameters: Parametrizable {
        public let code: String

        public init(
            code: String
        ) {
            self.code = code
        }
    }

    public struct Output: ATProtocolCodable {
        public let joinLinkPreview: ChatBskyGroupDefs.JoinLinkPreviewView

        /// Standard public initializer
        public init(
            joinLinkPreview: ChatBskyGroupDefs.JoinLinkPreviewView

        ) {
            self.joinLinkPreview = joinLinkPreview
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            joinLinkPreview = try container.decode(ChatBskyGroupDefs.JoinLinkPreviewView.self, forKey: .joinLinkPreview)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(joinLinkPreview, forKey: .joinLinkPreview)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let joinLinkPreviewValue = try joinLinkPreview.toCBORValue()
            map = map.adding(key: "joinLinkPreview", value: joinLinkPreviewValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case joinLinkPreview
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case invalidCode = "InvalidCode."
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

public extension ATProtoClient.Chat.Bsky.Group {
    // MARK: - getJoinLinkPreview

    /// [NOTE: This is under active development and should be considered unstable while this note is here]. Get public information about a group from an join link.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getJoinLinkPreview(input: ChatBskyGroupGetJoinLinkPreview.Parameters) async throws -> (responseCode: Int, data: ChatBskyGroupGetJoinLinkPreview.Output?) {
        let endpoint = "chat.bsky.group.getJoinLinkPreview"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.group.getJoinLinkPreview")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled via the status code / structured error parser below.
        if (200 ... 299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ChatBskyGroupGetJoinLinkPreview.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.group.getJoinLinkPreview: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
