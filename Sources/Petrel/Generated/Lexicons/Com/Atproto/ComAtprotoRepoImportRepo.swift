import Foundation



// lexicon: 1, id: com.atproto.repo.importRepo


public struct ComAtprotoRepoImportRepo { 

    public static let typeIdentifier = "com.atproto.repo.importRepo"
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



}

extension ATProtoClient.Com.Atproto.Repo {
    // MARK: - importRepo

    /// Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.
    /// 
    /// - Parameter data: The binary data to upload
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func importRepo(
        
        data: Data
        
    ) async throws -> Int {
        let endpoint = "com.atproto.repo.importRepo"
        
        let dataToUpload = data
        var headers: [String: String] = [
            "Content-Type": "application/vnd.ipld.car",
            "Content-Length": "\(dataToUpload.count)"
        ]
        
        

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: dataToUpload,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.repo.importRepo")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        return responseCode
        
    }
    
}
                           

