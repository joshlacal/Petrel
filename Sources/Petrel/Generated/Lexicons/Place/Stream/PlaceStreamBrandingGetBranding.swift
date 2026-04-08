import Foundation



// lexicon: 1, id: place.stream.branding.getBranding


public struct PlaceStreamBrandingGetBranding { 

    public static let typeIdentifier = "place.stream.branding.getBranding"
        
public struct BrandingAsset: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.branding.getBranding#brandingAsset"
            public let key: String
            public let mimeType: String
            public let url: String?
            public let data: String?
            public let width: Int?
            public let height: Int?

        public init(
            key: String, mimeType: String, url: String?, data: String?, width: Int?, height: Int?
        ) {
            self.key = key
            self.mimeType = mimeType
            self.url = url
            self.data = data
            self.width = width
            self.height = height
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.key = try container.decode(String.self, forKey: .key)
            } catch {
                LogManager.logError("Decoding error for required property 'key': \(error)")
                throw error
            }
            do {
                self.mimeType = try container.decode(String.self, forKey: .mimeType)
            } catch {
                LogManager.logError("Decoding error for required property 'mimeType': \(error)")
                throw error
            }
            do {
                self.url = try container.decodeIfPresent(String.self, forKey: .url)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'url': \(error)")
                throw error
            }
            do {
                self.data = try container.decodeIfPresent(String.self, forKey: .data)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'data': \(error)")
                throw error
            }
            do {
                self.width = try container.decodeIfPresent(Int.self, forKey: .width)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'width': \(error)")
                throw error
            }
            do {
                self.height = try container.decodeIfPresent(Int.self, forKey: .height)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'height': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(key, forKey: .key)
            try container.encode(mimeType, forKey: .mimeType)
            try container.encodeIfPresent(url, forKey: .url)
            try container.encodeIfPresent(data, forKey: .data)
            try container.encodeIfPresent(width, forKey: .width)
            try container.encodeIfPresent(height, forKey: .height)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(key)
            hasher.combine(mimeType)
            if let value = url {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = data {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = width {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = height {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if key != other.key {
                return false
            }
            if mimeType != other.mimeType {
                return false
            }
            if url != other.url {
                return false
            }
            if data != other.data {
                return false
            }
            if width != other.width {
                return false
            }
            if height != other.height {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let keyValue = try key.toCBORValue()
            map = map.adding(key: "key", value: keyValue)
            let mimeTypeValue = try mimeType.toCBORValue()
            map = map.adding(key: "mimeType", value: mimeTypeValue)
            if let value = url {
                let urlValue = try value.toCBORValue()
                map = map.adding(key: "url", value: urlValue)
            }
            if let value = data {
                let dataValue = try value.toCBORValue()
                map = map.adding(key: "data", value: dataValue)
            }
            if let value = width {
                let widthValue = try value.toCBORValue()
                map = map.adding(key: "width", value: widthValue)
            }
            if let value = height {
                let heightValue = try value.toCBORValue()
                map = map.adding(key: "height", value: heightValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case key
            case mimeType
            case url
            case data
            case width
            case height
        }
    }    
public struct Parameters: Parametrizable {
        public let broadcaster: DID?
        
        public init(
            broadcaster: DID? = nil
            ) {
            self.broadcaster = broadcaster
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let assets: [BrandingAsset]
        
        
        
        // Standard public initializer
        public init(
            
            
            assets: [BrandingAsset]
            
            
        ) {
            
            
            self.assets = assets
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.assets = try container.decode([BrandingAsset].self, forKey: .assets)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(assets, forKey: .assets)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let assetsValue = try assets.toCBORValue()
            map = map.adding(key: "assets", value: assetsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case assets
        }
        
    }




}



extension ATProtoClient.Place.Stream.Branding {
    // MARK: - getBranding

    /// Get all branding configuration for the broadcaster.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getBranding(input: PlaceStreamBrandingGetBranding.Parameters) async throws -> (responseCode: Int, data: PlaceStreamBrandingGetBranding.Output?) {
        let endpoint = "place.stream.branding.getBranding"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.branding.getBranding")
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
                let decodedData = try decoder.decode(PlaceStreamBrandingGetBranding.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.branding.getBranding: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

