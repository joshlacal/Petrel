import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// lexicon: 1, id: chat.bsky.actor.deleteAccount

public enum ChatBskyActorDeleteAccount {
    public static let typeIdentifier = "chat.bsky.actor.deleteAccount"

    public struct Output: ATProtocolCodable {
        // Empty output - no properties (response is {})

        // Standard public initializer
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
}

public extension ATProtoClient.Chat.Bsky.Actor {
    // MARK: - deleteAccount

    ///
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func deleteAccount(
    ) async throws -> (responseCode: Int, data: ChatBskyActorDeleteAccount.Output?) {
        let endpoint = "chat.bsky.actor.deleteAccount"

        var headers: [String: String] = [:]

        headers["Accept"] = "application/json"

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.actor.deleteAccount")
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
                let decodedData = try decoder.decode(ChatBskyActorDeleteAccount.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.actor.deleteAccount: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
