import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.unspecced.getTaggedSuggestions


public struct AppBskyUnspeccedGetTaggedSuggestions { 

    public static let typeIdentifier = "app.bsky.unspecced.getTaggedSuggestions"
        
public struct Suggestion: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.unspecced.getTaggedSuggestions#suggestion"
            public let tag: String
            public let subjectType: String
            public let subject: URI

        // Standard initializer
        public init(
            tag: String, subjectType: String, subject: URI
        ) {
            
            self.tag = tag
            self.subjectType = subjectType
            self.subject = subject
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.tag = try container.decode(String.self, forKey: .tag)
                
            } catch {
                LogManager.logError("Decoding error for property 'tag': \(error)")
                throw error
            }
            do {
                
                self.subjectType = try container.decode(String.self, forKey: .subjectType)
                
            } catch {
                LogManager.logError("Decoding error for property 'subjectType': \(error)")
                throw error
            }
            do {
                
                self.subject = try container.decode(URI.self, forKey: .subject)
                
            } catch {
                LogManager.logError("Decoding error for property 'subject': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(tag, forKey: .tag)
            
            
            try container.encode(subjectType, forKey: .subjectType)
            
            
            try container.encode(subject, forKey: .subject)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(tag)
            hasher.combine(subjectType)
            hasher.combine(subject)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.tag != other.tag {
                return false
            }
            
            
            if self.subjectType != other.subjectType {
                return false
            }
            
            
            if self.subject != other.subject {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case tag
            case subjectType
            case subject
        }
    }    
public struct Parameters: Parametrizable {
        
        public init(
            ) {
            
        }
    }    
    
public struct Output: ATProtocolCodable {
        
        
        public let suggestions: [Suggestion]
        
        
        
        // Standard public initializer
        public init(
            
            suggestions: [Suggestion]
            
            
        ) {
            
            self.suggestions = suggestions
            
            
        }
    }




}


extension ATProtoClient.App.Bsky.Unspecced {
    /// Get a list of suggestions (feeds and users) tagged with categories
    public func getTaggedSuggestions(input: AppBskyUnspeccedGetTaggedSuggestions.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetTaggedSuggestions.Output?) {
        let endpoint = "app.bsky.unspecced.getTaggedSuggestions"
        
        
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
        
        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetTaggedSuggestions.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
