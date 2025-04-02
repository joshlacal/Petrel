import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// lexicon: 1, id: com.atproto.repo.uploadBlob

public enum ComAtprotoRepoUploadBlob {
    public static let typeIdentifier = "com.atproto.repo.uploadBlob"

    public struct Output: ATProtocolCodable {
        public let blob: Blob

        // Standard public initializer
        public init(
            blob: Blob

        ) {
            self.blob = blob
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            blob = try container.decode(Blob.self, forKey: .blob)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(blob, forKey: .blob)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let blobValue = try (blob as? DAGCBOREncodable)?.toCBORValue() ?? blob
            map = map.adding(key: "blob", value: blobValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case blob
        }
    }
}

extension ATProtoClient.Com.Atproto.Repo {
    /// Upload a new blob, to be referenced from a repository record. The blob will be deleted if it is not referenced within a time window (eg, minutes). Blob restrictions (mimetype, size, etc) are enforced when the reference is created. Requires auth, implemented by PDS.
    public func uploadBlob(
        data: Data,
        mimeType: String,
        stripMetadata: Bool = true

    ) async throws -> (responseCode: Int, data: ComAtprotoRepoUploadBlob.Output?) {
        let endpoint = "com.atproto.repo.uploadBlob"

        var dataToUpload = data
        if stripMetadata, let strippedData = ImageMetadataStripper.stripMetadata(from: dataToUpload) {
            dataToUpload = strippedData
        }
        if mimeType.starts(with: "image/"), let compressedData = compressImage(dataToUpload) {
            dataToUpload = compressedData
        }
        var headers: [String: String] = [
            "Content-Type": mimeType,
            "Content-Length": "\(dataToUpload.count)",
        ]

        headers["Accept"] = "application/json"

        let requestData: Data? = nil
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: dataToUpload,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ComAtprotoRepoUploadBlob.Output.self, from: responseData)

        return (responseCode, decodedData)
    }

    private func compressImage(_ imageData: Data, maxSizeInBytes: Int = 1_000_000) -> Data? {
        #if canImport(UIKit)
            guard let image = UIImage(data: imageData) else { return nil }
            var compression: CGFloat = 1.0
            var compressedData = image.jpegData(compressionQuality: compression)
            while (compressedData?.count ?? 0) > maxSizeInBytes, compression > 0.1 {
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
                   let bitmapImage = NSBitmapImageRep(data: tiffRepresentation)
                {
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
