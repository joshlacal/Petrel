import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.server.refreshSession

public enum ComAtprotoServerRefreshSession {
    public static let typeIdentifier = "com.atproto.server.refreshSession"

    public struct Output: ATProtocolCodable {
        public let accessJwt: String

        public let refreshJwt: String

        public let handle: String

        public let did: String

        public let didDoc: DIDDocument?

        public let active: Bool?

        public let status: String?

        // Standard public initializer
        public init(
            accessJwt: String,

            refreshJwt: String,

            handle: String,

            did: String,

            didDoc: DIDDocument? = nil,

            active: Bool? = nil,

            status: String? = nil

        ) {
            self.accessJwt = accessJwt

            self.refreshJwt = refreshJwt

            self.handle = handle

            self.did = did

            self.didDoc = didDoc

            self.active = active

            self.status = status
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case accountTakedown = "AccountTakedown."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Refresh an authentication session. Requires auth using the 'refreshJwt' (not the 'accessJwt').
    func refreshSession(
    ) async throws -> (responseCode: Int, data: ComAtprotoServerRefreshSession.Output?) {
        let endpoint = "com.atproto.server.refreshSession"

        var headers: [String: String] = [:]

        headers["Accept"] = "application/json"

        let requestData: Data? = nil
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoServerRefreshSession.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
