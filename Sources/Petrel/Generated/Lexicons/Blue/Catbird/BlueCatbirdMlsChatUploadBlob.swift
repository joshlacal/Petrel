import Foundation


#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif



// lexicon: 1, id: blue.catbird.mlsChat.uploadBlob


public struct BlueCatbirdMlsChatUploadBlob { 

    public static let typeIdentifier = "blue.catbird.mlsChat.uploadBlob"
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
        
        
        public let blobId: String
        
        public let size: Int
        
        
        
        // Standard public initializer
        public init(
            
            
            blobId: String,
            
            size: Int
            
            
        ) {
            
            
            self.blobId = blobId
            
            self.size = size
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.blobId = try container.decode(String.self, forKey: .blobId)
            
            
            self.size = try container.decode(Int.self, forKey: .size)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(blobId, forKey: .blobId)
            
            
            try container.encode(size, forKey: .size)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let blobIdValue = try blobId.toCBORValue()
            map = map.adding(key: "blobId", value: blobIdValue)
            
            
            
            let sizeValue = try size.toCBORValue()
            map = map.adding(key: "size", value: sizeValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case blobId
            case size
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case quotaExceeded = "QuotaExceeded.User's blob storage quota has been exceeded (500MB per user)"
                case blobTooLarge = "BlobTooLarge.Blob exceeds maximum size (10MB)"
                case notAMember = "NotAMember.Uploader is not an active member of the target conversation"
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

extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - uploadBlob

    /// Upload an encrypted blob for image DM attachments Upload an encrypted blob to the blob store. The server assigns a blobId (UUIDv4) on success. Content-Type must be application/octet-stream. The blob bytes are opaque encrypted data — the server never sees plaintext. The uploader must be an active member of the target conversation.
    /// 
    /// - Parameters:
    ///   - data: The binary data to upload
    ///   - mimeType: The MIME type of the data being uploaded
    ///   - stripMetadata: Whether to strip metadata from images (default: true)
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func uploadBlob(
        
        data: Data,
        mimeType: String,
        stripMetadata: Bool = true
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatUploadBlob.Output?) {
        let endpoint = "blue.catbird.mlsChat.uploadBlob"
        
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
        
        
        headers["Accept"] = "application/json"
        

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: dataToUpload,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.uploadBlob")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatUploadBlob.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.uploadBlob: \(error)")
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
                           

