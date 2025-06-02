import Foundation

// lexicon: 1, id: app.bsky.video.getUploadLimits

public enum AppBskyVideoGetUploadLimits {
    public static let typeIdentifier = "app.bsky.video.getUploadLimits"

    public struct Output: ATProtocolCodable {
        public let canUpload: Bool

        public let remainingDailyVideos: Int?

        public let remainingDailyBytes: Int?

        public let message: String?

        public let error: String?

        // Standard public initializer
        public init(
            canUpload: Bool,

            remainingDailyVideos: Int? = nil,

            remainingDailyBytes: Int? = nil,

            message: String? = nil,

            error: String? = nil

        ) {
            self.canUpload = canUpload

            self.remainingDailyVideos = remainingDailyVideos

            self.remainingDailyBytes = remainingDailyBytes

            self.message = message

            self.error = error
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            canUpload = try container.decode(Bool.self, forKey: .canUpload)

            remainingDailyVideos = try container.decodeIfPresent(Int.self, forKey: .remainingDailyVideos)

            remainingDailyBytes = try container.decodeIfPresent(Int.self, forKey: .remainingDailyBytes)

            message = try container.decodeIfPresent(String.self, forKey: .message)

            error = try container.decodeIfPresent(String.self, forKey: .error)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(canUpload, forKey: .canUpload)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(remainingDailyVideos, forKey: .remainingDailyVideos)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(remainingDailyBytes, forKey: .remainingDailyBytes)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(message, forKey: .message)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(error, forKey: .error)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let canUploadValue = try canUpload.toCBORValue()
            map = map.adding(key: "canUpload", value: canUploadValue)

            if let value = remainingDailyVideos {
                // Encode optional property even if it's an empty array for CBOR
                let remainingDailyVideosValue = try value.toCBORValue()
                map = map.adding(key: "remainingDailyVideos", value: remainingDailyVideosValue)
            }

            if let value = remainingDailyBytes {
                // Encode optional property even if it's an empty array for CBOR
                let remainingDailyBytesValue = try value.toCBORValue()
                map = map.adding(key: "remainingDailyBytes", value: remainingDailyBytesValue)
            }

            if let value = message {
                // Encode optional property even if it's an empty array for CBOR
                let messageValue = try value.toCBORValue()
                map = map.adding(key: "message", value: messageValue)
            }

            if let value = error {
                // Encode optional property even if it's an empty array for CBOR
                let errorValue = try value.toCBORValue()
                map = map.adding(key: "error", value: errorValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case canUpload
            case remainingDailyVideos
            case remainingDailyBytes
            case message
            case error
        }
    }
}

public extension ATProtoClient.App.Bsky.Video {
    // MARK: - getUploadLimits

    /// Get video upload limits for the authenticated user.
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getUploadLimits() async throws -> (responseCode: Int, data: AppBskyVideoGetUploadLimits.Output?) {
        let endpoint = "app.bsky.video.getUploadLimits"

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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyVideoGetUploadLimits.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
