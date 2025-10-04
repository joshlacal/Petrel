import Foundation

// lexicon: 1, id: com.atproto.repo.importRepo

public enum ComAtprotoRepoImportRepo {
    public static let typeIdentifier = "com.atproto.repo.importRepo"
    public struct Input: ATProtocolCodable {
        public let data: Data

        // Standard public initializer
        public init(data: Data) {
            self.data = data
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            data = try container.decode(Data.self, forKey: .data)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(data, forKey: .data)
        }

        private enum CodingKeys: String, CodingKey {
            case data
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let dataValue = try data.toCBORValue()
            map = map.adding(key: "data", value: dataValue)

            return map
        }
    }
}

public extension ATProtoClient.Com.Atproto.Repo {
    // MARK: - importRepo

    /// Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.
    ///
    /// - Parameter data: The binary data to upload
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func importRepo(
        data: Data

    ) async throws -> Int {
        let endpoint = "com.atproto.repo.importRepo"

        let dataToUpload = data
        var headers: [String: String] = [
            "Content-Type": "application/vnd.ipld.car",
            "Content-Length": "\(dataToUpload.count)",
        ]

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: dataToUpload,
            queryItems: nil
        )

        let (_, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode
        return responseCode
    }
}
