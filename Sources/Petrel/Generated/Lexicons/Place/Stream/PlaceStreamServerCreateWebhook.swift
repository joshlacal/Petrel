import Foundation



// lexicon: 1, id: place.stream.server.createWebhook


public struct PlaceStreamServerCreateWebhook { 

    public static let typeIdentifier = "place.stream.server.createWebhook"
public struct Input: ATProtocolCodable {
        public let url: URI
        public let events: [String]
        public let active: Bool?
        public let prefix: String?
        public let suffix: String?
        public let rewrite: [PlaceStreamServerDefs.RewriteRule]?
        public let name: String?
        public let description: String?
        public let muteWords: [String]?

        /// Standard public initializer
        public init(url: URI, events: [String], active: Bool? = nil, prefix: String? = nil, suffix: String? = nil, rewrite: [PlaceStreamServerDefs.RewriteRule]? = nil, name: String? = nil, description: String? = nil, muteWords: [String]? = nil) {
            self.url = url
            self.events = events
            self.active = active
            self.prefix = prefix
            self.suffix = suffix
            self.rewrite = rewrite
            self.name = name
            self.description = description
            self.muteWords = muteWords
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.url = try container.decode(URI.self, forKey: .url)
            self.events = try container.decode([String].self, forKey: .events)
            self.active = try container.decodeIfPresent(Bool.self, forKey: .active)
            self.prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
            self.suffix = try container.decodeIfPresent(String.self, forKey: .suffix)
            self.rewrite = try container.decodeIfPresent([PlaceStreamServerDefs.RewriteRule].self, forKey: .rewrite)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
            self.description = try container.decodeIfPresent(String.self, forKey: .description)
            self.muteWords = try container.decodeIfPresent([String].self, forKey: .muteWords)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(url, forKey: .url)
            try container.encode(events, forKey: .events)
            try container.encodeIfPresent(active, forKey: .active)
            try container.encodeIfPresent(prefix, forKey: .prefix)
            try container.encodeIfPresent(suffix, forKey: .suffix)
            try container.encodeIfPresent(rewrite, forKey: .rewrite)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(muteWords, forKey: .muteWords)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let urlValue = try url.toCBORValue()
            map = map.adding(key: "url", value: urlValue)
            let eventsValue = try events.toCBORValue()
            map = map.adding(key: "events", value: eventsValue)
            if let value = active {
                let activeValue = try value.toCBORValue()
                map = map.adding(key: "active", value: activeValue)
            }
            if let value = prefix {
                let prefixValue = try value.toCBORValue()
                map = map.adding(key: "prefix", value: prefixValue)
            }
            if let value = suffix {
                let suffixValue = try value.toCBORValue()
                map = map.adding(key: "suffix", value: suffixValue)
            }
            if let value = rewrite {
                let rewriteValue = try value.toCBORValue()
                map = map.adding(key: "rewrite", value: rewriteValue)
            }
            if let value = name {
                let nameValue = try value.toCBORValue()
                map = map.adding(key: "name", value: nameValue)
            }
            if let value = description {
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            if let value = muteWords {
                let muteWordsValue = try value.toCBORValue()
                map = map.adding(key: "muteWords", value: muteWordsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case url
            case events
            case active
            case prefix
            case suffix
            case rewrite
            case name
            case description
            case muteWords
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let webhook: PlaceStreamServerDefs.Webhook
        
        
        
        // Standard public initializer
        public init(
            
            
            webhook: PlaceStreamServerDefs.Webhook
            
            
        ) {
            
            
            self.webhook = webhook
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.webhook = try container.decode(PlaceStreamServerDefs.Webhook.self, forKey: .webhook)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(webhook, forKey: .webhook)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let webhookValue = try webhook.toCBORValue()
            map = map.adding(key: "webhook", value: webhookValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case webhook
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidUrl = "InvalidUrl.The provided webhook URL is invalid or unreachable."
                case duplicateWebhook = "DuplicateWebhook.A webhook with this URL already exists for this user."
                case tooManyWebhooks = "TooManyWebhooks.The user has reached their maximum number of webhooks."
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}

extension ATProtoClient.Place.Stream.Server {
    // MARK: - createWebhook

    /// Create a new webhook for receiving Streamplace events.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func createWebhook(
        
        input: PlaceStreamServerCreateWebhook.Input
        
    ) async throws -> (responseCode: Int, data: PlaceStreamServerCreateWebhook.Output?) {
        let endpoint = "place.stream.server.createWebhook"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        
        let requestData: Data? = try JSONEncoder().encode(input)
        
        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.server.createWebhook")
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
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(PlaceStreamServerCreateWebhook.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.server.createWebhook: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

