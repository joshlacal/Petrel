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

            if let value = url {
                try container.encode(value, forKey: .url)
            }
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

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = url {
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

            if let value = role {
                try container.encode(value, forKey: .role)
            }
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

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = role {
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

            if let value = appview {
                try container.encode(value, forKey: .appview)
            }

            if let value = pds {
                try container.encode(value, forKey: .pds)
            }

            if let value = blobDivert {
                try container.encode(value, forKey: .blobDivert)
            }

            if let value = chat {
                try container.encode(value, forKey: .chat)
            }

            if let value = viewer {
                try container.encode(value, forKey: .viewer)
            }
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            if let value = appview {
                let appviewValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "appview", value: appviewValue)
            }

            if let value = pds {
                let pdsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "pds", value: pdsValue)
            }

            if let value = blobDivert {
                let blobDivertValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "blobDivert", value: blobDivertValue)
            }

            if let value = chat {
                let chatValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "chat", value: chatValue)
            }

            if let value = viewer {
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
