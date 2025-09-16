import Foundation



// lexicon: 1, id: app.bsky.graph.getListsWithMembership


public struct AppBskyGraphGetListsWithMembership { 

    public static let typeIdentifier = "app.bsky.graph.getListsWithMembership"
        
public struct ListWithMembership: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.graph.getListsWithMembership#listWithMembership"
            public let list: AppBskyGraphDefs.ListView
            public let listItem: AppBskyGraphDefs.ListItemView?

        // Standard initializer
        public init(
            list: AppBskyGraphDefs.ListView, listItem: AppBskyGraphDefs.ListItemView?
        ) {
            
            self.list = list
            self.listItem = listItem
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.list = try container.decode(AppBskyGraphDefs.ListView.self, forKey: .list)
                
            } catch {
                LogManager.logError("Decoding error for property 'list': \(error)")
                throw error
            }
            do {
                
                self.listItem = try container.decodeIfPresent(AppBskyGraphDefs.ListItemView.self, forKey: .listItem)
                
            } catch {
                LogManager.logError("Decoding error for property 'listItem': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(list, forKey: .list)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(listItem, forKey: .listItem)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(list)
            if let value = listItem {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.list != other.list {
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

            
            
            
            let listValue = try list.toCBORValue()
            map = map.adding(key: "list", value: listValue)
            
            
            
            if let value = listItem {
                // Encode optional property even if it's an empty array for CBOR
                
                let listItemValue = try value.toCBORValue()
                map = map.adding(key: "listItem", value: listItemValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case list
            case listItem
        }
    }    
public struct Parameters: Parametrizable {
        public let actor: ATIdentifier
        public let limit: Int?
        public let cursor: String?
        public let purposes: [String]?
        
        public init(
            actor: ATIdentifier, 
            limit: Int? = nil, 
            cursor: String? = nil, 
            purposes: [String]? = nil
            ) {
            self.actor = actor
            self.limit = limit
            self.cursor = cursor
            self.purposes = purposes
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let listsWithMembership: [ListWithMembership]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            listsWithMembership: [ListWithMembership]
            
            
        ) {
            
            self.cursor = cursor
            
            self.listsWithMembership = listsWithMembership
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.listsWithMembership = try container.decode([ListWithMembership].self, forKey: .listsWithMembership)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            try container.encode(listsWithMembership, forKey: .listsWithMembership)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            
            
            let listsWithMembershipValue = try listsWithMembership.toCBORValue()
            map = map.adding(key: "listsWithMembership", value: listsWithMembershipValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case listsWithMembership
            
        }
    }




}


extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getListsWithMembership

    /// Enumerates the lists created by the session user, and includes membership information about `actor` in those lists. Only supports curation and moderation lists (no reference lists, used in starter packs). Requires auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getListsWithMembership(input: AppBskyGraphGetListsWithMembership.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetListsWithMembership.Output?) {
        let endpoint = "app.bsky.graph.getListsWithMembership"

        
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
                let decodedData = try decoder.decode(AppBskyGraphGetListsWithMembership.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.graph.getListsWithMembership: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
