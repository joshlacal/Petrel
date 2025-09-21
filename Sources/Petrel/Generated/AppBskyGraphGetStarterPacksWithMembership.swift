import Foundation



// lexicon: 1, id: app.bsky.graph.getStarterPacksWithMembership


public struct AppBskyGraphGetStarterPacksWithMembership { 

    public static let typeIdentifier = "app.bsky.graph.getStarterPacksWithMembership"
        
public struct StarterPackWithMembership: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.graph.getStarterPacksWithMembership#starterPackWithMembership"
            public let starterPack: AppBskyGraphDefs.StarterPackView
            public let listItem: AppBskyGraphDefs.ListItemView?

        // Standard initializer
        public init(
            starterPack: AppBskyGraphDefs.StarterPackView, listItem: AppBskyGraphDefs.ListItemView?
        ) {
            
            self.starterPack = starterPack
            self.listItem = listItem
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.starterPack = try container.decode(AppBskyGraphDefs.StarterPackView.self, forKey: .starterPack)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'starterPack': \(error)")
                
                throw error
            }
            do {
                
                self.listItem = try container.decodeIfPresent(AppBskyGraphDefs.ListItemView.self, forKey: .listItem)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'listItem': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(starterPack, forKey: .starterPack)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(listItem, forKey: .listItem)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(starterPack)
            if let value = listItem {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.starterPack != other.starterPack {
                return false
            }
            
            
            if listItem != other.listItem {
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

            
            
            
            let starterPackValue = try starterPack.toCBORValue()
            map = map.adding(key: "starterPack", value: starterPackValue)
            
            
            
            if let value = listItem {
                // Encode optional property even if it's an empty array for CBOR
                
                let listItemValue = try value.toCBORValue()
                map = map.adding(key: "listItem", value: listItemValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case starterPack
            case listItem
        }
    }    
public struct Parameters: Parametrizable {
        public let actor: ATIdentifier
        public let limit: Int?
        public let cursor: String?
        
        public init(
            actor: ATIdentifier, 
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.actor = actor
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let starterPacksWithMembership: [StarterPackWithMembership]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            starterPacksWithMembership: [StarterPackWithMembership]
            
            
        ) {
            
            self.cursor = cursor
            
            self.starterPacksWithMembership = starterPacksWithMembership
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.starterPacksWithMembership = try container.decode([StarterPackWithMembership].self, forKey: .starterPacksWithMembership)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            try container.encode(starterPacksWithMembership, forKey: .starterPacksWithMembership)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            
            
            let starterPacksWithMembershipValue = try starterPacksWithMembership.toCBORValue()
            map = map.adding(key: "starterPacksWithMembership", value: starterPacksWithMembershipValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case starterPacksWithMembership
            
        }
    }




}


extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getStarterPacksWithMembership

    /// Enumerates the starter packs created by the session user, and includes membership information about `actor` in those starter packs. Requires auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getStarterPacksWithMembership(input: AppBskyGraphGetStarterPacksWithMembership.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetStarterPacksWithMembership.Output?) {
        let endpoint = "app.bsky.graph.getStarterPacksWithMembership"

        
        let queryItems = input.asQueryItems()
        
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
                let decodedData = try decoder.decode(AppBskyGraphGetStarterPacksWithMembership.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.graph.getStarterPacksWithMembership: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
