import Foundation

// lexicon: 1, id: blue.catbird.mls.getKeyPackages

public enum BlueCatbirdMlsGetKeyPackages {
    public static let typeIdentifier = "blue.catbird.mls.getKeyPackages"
    public struct Parameters: Parametrizable {
        public let dids: [DID]
        public let cipherSuite: String?

        public init(
            dids: [DID],
            cipherSuite: String? = nil
        ) {
            self.dids = dids
            self.cipherSuite = cipherSuite
        }
    }

    public struct Output: ATProtocolCodable {
        public let keyPackages: [BlueCatbirdMlsDefs.KeyPackageRef]

        public let missing: [DID]?

        /// Standard public initializer
        public init(
            keyPackages: [BlueCatbirdMlsDefs.KeyPackageRef],

            missing: [DID]? = nil

        ) {
            self.keyPackages = keyPackages

            self.missing = missing
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            keyPackages = try container.decode([BlueCatbirdMlsDefs.KeyPackageRef].self, forKey: .keyPackages)

            missing = try container.decodeIfPresent([DID].self, forKey: .missing)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(keyPackages, forKey: .keyPackages)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(missing, forKey: .missing)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let keyPackagesValue = try keyPackages.toCBORValue()
            map = map.adding(key: "keyPackages", value: keyPackagesValue)

            if let value = missing {
                // Encode optional property even if it's an empty array for CBOR
                let missingValue = try value.toCBORValue()
                map = map.adding(key: "missing", value: missingValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case keyPackages
            case missing
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case tooManyDids = "TooManyDids.Too many DIDs requested"
        case invalidDid = "InvalidDid.One or more DIDs are invalid"
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getKeyPackages

    /// Retrieve key packages for one or more DIDs to add them to conversations
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getKeyPackages(input: BlueCatbirdMlsGetKeyPackages.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetKeyPackages.Output?) {
        let endpoint = "blue.catbird.mls.getKeyPackages"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getKeyPackages")
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
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(BlueCatbirdMlsGetKeyPackages.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getKeyPackages: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
