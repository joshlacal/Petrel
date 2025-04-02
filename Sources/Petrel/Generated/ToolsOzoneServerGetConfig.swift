import Foundation

// lexicon: 1, id: tools.ozone.server.getConfig

public enum ToolsOzoneServerGetConfig {
    public static let typeIdentifier = "tools.ozone.server.getConfig"

    public struct ServiceConfig: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.server.getConfig#serviceConfig"
        public let url: URI?

        // Standard initializer
        public init(
            url: URI?
        ) {
            self.url = url
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                url = try container.decodeIfPresent(URI.self, forKey: .url)

            } catch {
                LogManager.logError("Decoding error for property 'url': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(url, forKey: .url)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = url {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if url != other.url {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            if let value = url {
                // Encode optional property even if it's an empty array for CBOR

                let urlValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "url", value: urlValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case url
        }
    }

    public struct ViewerConfig: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.server.getConfig#viewerConfig"
        public let role: String?

        // Standard initializer
        public init(
            role: String?
        ) {
            self.role = role
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                role = try container.decodeIfPresent(String.self, forKey: .role)

            } catch {
                LogManager.logError("Decoding error for property 'role': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(role, forKey: .role)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = role {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if role != other.role {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            if let value = role {
                // Encode optional property even if it's an empty array for CBOR

                let roleValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "role", value: roleValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case role
        }
    }

    public struct Output: ATProtocolCodable {
        public let appview: ServiceConfig?

        public let pds: ServiceConfig?

        public let blobDivert: ServiceConfig?

        public let chat: ServiceConfig?

        public let viewer: ViewerConfig?

        // Standard public initializer
        public init(
            appview: ServiceConfig? = nil,

            pds: ServiceConfig? = nil,

            blobDivert: ServiceConfig? = nil,

            chat: ServiceConfig? = nil,

            viewer: ViewerConfig? = nil

        ) {
            self.appview = appview

            self.pds = pds

            self.blobDivert = blobDivert

            self.chat = chat

            self.viewer = viewer
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            appview = try container.decodeIfPresent(ServiceConfig.self, forKey: .appview)

            pds = try container.decodeIfPresent(ServiceConfig.self, forKey: .pds)

            blobDivert = try container.decodeIfPresent(ServiceConfig.self, forKey: .blobDivert)

            chat = try container.decodeIfPresent(ServiceConfig.self, forKey: .chat)

            viewer = try container.decodeIfPresent(ViewerConfig.self, forKey: .viewer)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(appview, forKey: .appview)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(pds, forKey: .pds)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(blobDivert, forKey: .blobDivert)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(chat, forKey: .chat)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(viewer, forKey: .viewer)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = appview {
                // Encode optional property even if it's an empty array for CBOR

                let appviewValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "appview", value: appviewValue)
            }

            if let value = pds {
                // Encode optional property even if it's an empty array for CBOR

                let pdsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "pds", value: pdsValue)
            }

            if let value = blobDivert {
                // Encode optional property even if it's an empty array for CBOR

                let blobDivertValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "blobDivert", value: blobDivertValue)
            }

            if let value = chat {
                // Encode optional property even if it's an empty array for CBOR

                let chatValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "chat", value: chatValue)
            }

            if let value = viewer {
                // Encode optional property even if it's an empty array for CBOR

                let viewerValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "viewer", value: viewerValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case appview
            case pds
            case blobDivert
            case chat
            case viewer
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Server {
    /// Get details about ozone's server configuration.
    func getConfig() async throws -> (responseCode: Int, data: ToolsOzoneServerGetConfig.Output?) {
        let endpoint = "tools.ozone.server.getConfig"

        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
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
        let decodedData = try? decoder.decode(ToolsOzoneServerGetConfig.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
