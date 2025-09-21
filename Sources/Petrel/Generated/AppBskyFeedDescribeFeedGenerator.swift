import Foundation



// lexicon: 1, id: app.bsky.feed.describeFeedGenerator


public struct AppBskyFeedDescribeFeedGenerator { 

    public static let typeIdentifier = "app.bsky.feed.describeFeedGenerator"
        
public struct Feed: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.describeFeedGenerator#feed"
            public let uri: ATProtocolURI

        // Standard initializer
        public init(
            uri: ATProtocolURI
        ) {
            
            self.uri = uri
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(uri, forKey: .uri)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.uri != other.uri {
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

            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
        }
    }
        
public struct Links: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.describeFeedGenerator#links"
            public let privacyPolicy: String?
            public let termsOfService: String?

        // Standard initializer
        public init(
            privacyPolicy: String?, termsOfService: String?
        ) {
            
            self.privacyPolicy = privacyPolicy
            self.termsOfService = termsOfService
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.privacyPolicy = try container.decodeIfPresent(String.self, forKey: .privacyPolicy)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'privacyPolicy': \(error)")
                
                throw error
            }
            do {
                
                self.termsOfService = try container.decodeIfPresent(String.self, forKey: .termsOfService)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'termsOfService': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(privacyPolicy, forKey: .privacyPolicy)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(termsOfService, forKey: .termsOfService)
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = privacyPolicy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = termsOfService {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if privacyPolicy != other.privacyPolicy {
                return false
            }
            
            
            if termsOfService != other.termsOfService {
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

            
            
            if let value = privacyPolicy {
                // Encode optional property even if it's an empty array for CBOR
                
                let privacyPolicyValue = try value.toCBORValue()
                map = map.adding(key: "privacyPolicy", value: privacyPolicyValue)
            }
            
            
            
            if let value = termsOfService {
                // Encode optional property even if it's an empty array for CBOR
                
                let termsOfServiceValue = try value.toCBORValue()
                map = map.adding(key: "termsOfService", value: termsOfServiceValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case privacyPolicy
            case termsOfService
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let did: DID
        
        public let feeds: [Feed]
        
        public let links: Links?
        
        
        
        // Standard public initializer
        public init(
            
            did: DID,
            
            feeds: [Feed],
            
            links: Links? = nil
            
            
        ) {
            
            self.did = did
            
            self.feeds = feeds
            
            self.links = links
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.did = try container.decode(DID.self, forKey: .did)
            
            
            self.feeds = try container.decode([Feed].self, forKey: .feeds)
            
            
            self.links = try container.decodeIfPresent(Links.self, forKey: .links)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(did, forKey: .did)
            
            
            try container.encode(feeds, forKey: .feeds)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(links, forKey: .links)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            let feedsValue = try feeds.toCBORValue()
            map = map.adding(key: "feeds", value: feedsValue)
            
            
            
            if let value = links {
                // Encode optional property even if it's an empty array for CBOR
                let linksValue = try value.toCBORValue()
                map = map.adding(key: "links", value: linksValue)
            }
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case did
            case feeds
            case links
            
        }
    }




}


extension ATProtoClient.App.Bsky.Feed {
    // MARK: - describeFeedGenerator

    /// Get information about a feed generator, including policies and offered feed URIs. Does not require auth; implemented by Feed Generator services (not App View).
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func describeFeedGenerator() async throws -> (responseCode: Int, data: AppBskyFeedDescribeFeedGenerator.Output?) {
        let endpoint = "app.bsky.feed.describeFeedGenerator"

        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        
        let (responseData, response) = try await networkService.performRequest(urlRequest)
        
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyFeedDescribeFeedGenerator.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.feed.describeFeedGenerator: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
