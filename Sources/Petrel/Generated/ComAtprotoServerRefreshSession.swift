import Foundation

// lexicon: 1, id: com.atproto.server.refreshSession

public enum ComAtprotoServerRefreshSession {
    public static let typeIdentifier = "com.atproto.server.refreshSession"

    public struct Output: ATProtocolCodable {
        public let accessJwt: String

        public let refreshJwt: String

        public let handle: Handle

        public let did: DID

        public let didDoc: DIDDocument?

        public let active: Bool?

        public let status: String?

        // Standard public initializer
        public init(
            accessJwt: String,

            refreshJwt: String,

            handle: Handle,

            did: DID,

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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            accessJwt = try container.decode(String.self, forKey: .accessJwt)

            refreshJwt = try container.decode(String.self, forKey: .refreshJwt)

            handle = try container.decode(Handle.self, forKey: .handle)

            did = try container.decode(DID.self, forKey: .did)

            didDoc = try container.decodeIfPresent(DIDDocument.self, forKey: .didDoc)

            active = try container.decodeIfPresent(Bool.self, forKey: .active)

            status = try container.decodeIfPresent(String.self, forKey: .status)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(accessJwt, forKey: .accessJwt)

            try container.encode(refreshJwt, forKey: .refreshJwt)

            try container.encode(handle, forKey: .handle)

            try container.encode(did, forKey: .did)

            if let value = didDoc {
                try container.encode(value, forKey: .didDoc)
            }

            if let value = active {
                try container.encode(value, forKey: .active)
            }

            if let value = status {
                try container.encode(value, forKey: .status)
            }
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let accessJwtValue = try (accessJwt as? DAGCBOREncodable)?.toCBORValue() ?? accessJwt
            map = map.adding(key: "accessJwt", value: accessJwtValue)

            let refreshJwtValue = try (refreshJwt as? DAGCBOREncodable)?.toCBORValue() ?? refreshJwt
            map = map.adding(key: "refreshJwt", value: refreshJwtValue)

            let handleValue = try (handle as? DAGCBOREncodable)?.toCBORValue() ?? handle
            map = map.adding(key: "handle", value: handleValue)

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            if let value = didDoc {
                let didDocValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "didDoc", value: didDocValue)
            }

            if let value = active {
                let activeValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "active", value: activeValue)
            }

            if let value = status {
                let statusValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "status", value: statusValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case accessJwt
            case refreshJwt
            case handle
            case did
            case didDoc
            case active
            case status
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
