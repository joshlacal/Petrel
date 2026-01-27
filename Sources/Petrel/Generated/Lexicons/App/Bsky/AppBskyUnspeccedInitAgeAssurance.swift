import Foundation



// lexicon: 1, id: app.bsky.unspecced.initAgeAssurance


public struct AppBskyUnspeccedInitAgeAssurance { 

    public static let typeIdentifier = "app.bsky.unspecced.initAgeAssurance"
public struct Input: ATProtocolCodable {
            public let email: String
            public let language: String
            public let countryCode: String

            // Standard public initializer
            public init(email: String, language: String, countryCode: String) {
                self.email = email
                self.language = language
                self.countryCode = countryCode
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.email = try container.decode(String.self, forKey: .email)
                
                
                self.language = try container.decode(String.self, forKey: .language)
                
                
                self.countryCode = try container.decode(String.self, forKey: .countryCode)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(email, forKey: .email)
                
                
                try container.encode(language, forKey: .language)
                
                
                try container.encode(countryCode, forKey: .countryCode)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case email
                case language
                case countryCode
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let emailValue = try email.toCBORValue()
                map = map.adding(key: "email", value: emailValue)
                
                
                
                let languageValue = try language.toCBORValue()
                map = map.adding(key: "language", value: languageValue)
                
                
                
                let countryCodeValue = try countryCode.toCBORValue()
                map = map.adding(key: "countryCode", value: countryCodeValue)
                
                

                return map
            }
        }
    public typealias Output = AppBskyUnspeccedDefs.AgeAssuranceState
            
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidEmail = "InvalidEmail."
                case didTooLong = "DidTooLong."
                case invalidInitiation = "InvalidInitiation."
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

extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - initAgeAssurance

    /// Initiate age assurance for an account. This is a one-time action that will start the process of verifying the user's age.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func initAgeAssurance(
        
        input: AppBskyUnspeccedInitAgeAssurance.Input
        
    ) async throws -> (responseCode: Int, data: AppBskyUnspeccedInitAgeAssurance.Output?) {
        let endpoint = "app.bsky.unspecced.initAgeAssurance"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.unspecced.initAgeAssurance")
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
                let decodedData = try decoder.decode(AppBskyUnspeccedInitAgeAssurance.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.unspecced.initAgeAssurance: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

