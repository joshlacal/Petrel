import Foundation


#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif



// lexicon: 1, id: place.stream.playback.whep


public struct PlaceStreamPlaybackWhep { 

    public static let typeIdentifier = "place.stream.playback.whep"
public struct Input: ATProtocolCodable {
        public let data: Data

        /// Standard public initializer
        public init(data: Data) {
            self.data = data
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.data = try container.decode(Data.self, forKey: .data)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(data, forKey: .data)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let dataValue = try data.toCBORValue()
            map = map.adding(key: "data", value: dataValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case data
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let data: Data
        
        
        
        // Standard public initializer
        public init(
            
            
            data: Data
            
            
        ) {
            
            
            self.data = data
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.data = try container.decode(Data.self, forKey: .data)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(data, forKey: .data)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let dataValue = try data.toCBORValue()
            map = map.adding(key: "data", value: dataValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case data
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case unauthorized = "Unauthorized.This user may not play this stream."
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

extension ATProtoClient.Place.Stream.Playback {
    // MARK: - whep

    /// Play a stream over WebRTC using WHEP.
    /// 
    /// - Parameters:
    ///   - data: The binary data to upload
    ///   - mimeType: The MIME type of the data being uploaded
    ///   - stripMetadata: Whether to strip metadata from images (default: true)
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func whep(
        
        data: Data,
        mimeType: String,
        stripMetadata: Bool = true
        
    ) async throws -> (responseCode: Int, data: PlaceStreamPlaybackWhep.Output?) {
        let endpoint = "place.stream.playback.whep"
        
        var dataToUpload = data
        if stripMetadata, let strippedData = ImageMetadataStripper.stripMetadata(from: dataToUpload) {
            dataToUpload = strippedData
        }
        if mimeType.starts(with: "image/"), let compressedData = compressImage(dataToUpload) {
            dataToUpload = compressedData
        }
        var headers: [String: String] = [
            "Content-Type": mimeType,
            "Content-Length": "\(dataToUpload.count)"
        ]
        
        
        headers["Accept"] = "*/*"
        

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: dataToUpload,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.playback.whep")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "*/*", actual: "nil")
        }

        if !contentType.lowercased().contains("*/*") {
            throw NetworkError.invalidContentType(expected: "*/*", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decodedData = PlaceStreamPlaybackWhep.Output(data: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.playback.whep: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
    /// Compresses an image while maintaining reasonable quality
    /// - Parameters:
    ///   - imageData: The original image data
    ///   - maxSizeInBytes: The maximum target size in bytes (default: 1MB)
    /// - Returns: Compressed image data, or nil if compression failed
    private func compressImage(_ imageData: Data, maxSizeInBytes: Int = 1000000) -> Data? {
        #if canImport(UIKit)
        guard let image = UIImage(data: imageData) else { return nil }
        var compression: CGFloat = 1.0
        var compressedData = image.jpegData(compressionQuality: compression)
        while (compressedData?.count ?? 0) > maxSizeInBytes && compression > 0.1 {
            compression -= 0.1
            compressedData = image.jpegData(compressionQuality: compression)
        }
        return compressedData
        #elseif canImport(AppKit)
        guard let image = NSImage(data: imageData) else { return nil }
        var compression: CGFloat = 1.0
        var compressedData: Data?
        repeat {
            if let tiffRepresentation = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) {
                compressedData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: compression])
            }
            compression -= 0.1
        } while (compressedData?.count ?? 0) > maxSizeInBytes && compression > 0.1
        return compressedData
        #else
        LogManager.logError("Image compression not supported on this platform")
        return nil
        #endif
    }
    
}
                           

