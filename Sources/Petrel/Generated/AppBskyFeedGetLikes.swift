import Foundation



// lexicon: 1, id: app.bsky.feed.getLikes


public struct AppBskyFeedGetLikes { 

    public static let typeIdentifier = "app.bsky.feed.getLikes"
        
public struct Like: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.getLikes#like"
            public let indexedAt: ATProtocolDate
            public let createdAt: ATProtocolDate
            public let actor: AppBskyActorDefs.ProfileView

        // Standard initializer
        public init(
            indexedAt: ATProtocolDate, createdAt: ATProtocolDate, actor: AppBskyActorDefs.ProfileView
        ) {
            
            self.indexedAt = indexedAt
            self.createdAt = createdAt
            self.actor = actor
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                
                self.actor = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .actor)
                
            } catch {
                LogManager.logError("Decoding error for property 'actor': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(indexedAt, forKey: .indexedAt)
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
            try container.encode(actor, forKey: .actor)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(indexedAt)
            hasher.combine(createdAt)
            hasher.combine(actor)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.indexedAt != other.indexedAt {
                return false
            }
            
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            
            if self.actor != other.actor {
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
            
            
            
            let indexedAtValue = try (indexedAt as? DAGCBOREncodable)?.toCBORValue() ?? indexedAt
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            
            
            
            
            let createdAtValue = try (createdAt as? DAGCBOREncodable)?.toCBORValue() ?? createdAt
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            
            
            
            let actorValue = try (actor as? DAGCBOREncodable)?.toCBORValue() ?? actor
            map = map.adding(key: "actor", value: actorValue)
            
            
            
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case indexedAt
            case createdAt
            case actor
        }
    }    
public struct Parameters: Parametrizable {
        public let uri: ATProtocolURI
        public let cid: CID?
        public let limit: Int?
        public let cursor: String?
        
        public init(
            uri: ATProtocolURI, 
            cid: CID? = nil, 
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.uri = uri
            self.cid = cid
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let uri: ATProtocolURI
        
        public let cid: CID?
        
        public let cursor: String?
        
        public let likes: [Like]
        
        
        
        // Standard public initializer
        public init(
            
            uri: ATProtocolURI,
            
            cid: CID? = nil,
            
            cursor: String? = nil,
            
            likes: [Like]
            
            
        ) {
            
            self.uri = uri
            
            self.cid = cid
            
            self.cursor = cursor
            
            self.likes = likes
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            
            
            self.cid = try container.decodeIfPresent(CID.self, forKey: .cid)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.likes = try container.decode([Like].self, forKey: .likes)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(uri, forKey: .uri)
            
            
            if let value = cid {
                
                try container.encode(value, forKey: .cid)
                
            }
            
            
            if let value = cursor {
                
                try container.encode(value, forKey: .cursor)
                
            }
            
            
            try container.encode(likes, forKey: .likes)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let uriValue = try (uri as? DAGCBOREncodable)?.toCBORValue() ?? uri
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            if let value = cid {
                
                
                let cidValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cid", value: cidValue)
                
            }
            
            
            
            if let value = cursor {
                
                
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
                
            }
            
            
            
            
            let likesValue = try (likes as? DAGCBOREncodable)?.toCBORValue() ?? likes
            map = map.adding(key: "likes", value: likesValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case uri
            case cid
            case cursor
            case likes
            
        }
    }




}


extension ATProtoClient.App.Bsky.Feed {
    /// Get like records which reference a subject (by AT-URI and CID).
    public func getLikes(input: AppBskyFeedGetLikes.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetLikes.Output?) {
        let endpoint = "app.bsky.feed.getLikes"
        
        
        let queryItems = input.asQueryItems()
        
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
        let decodedData = try? decoder.decode(AppBskyFeedGetLikes.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
