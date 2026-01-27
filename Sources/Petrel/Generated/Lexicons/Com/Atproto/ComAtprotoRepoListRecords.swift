import Foundation

// lexicon: 1, id: com.atproto.repo.listRecords

public enum ComAtprotoRepoListRecords {
    public static let typeIdentifier = "com.atproto.repo.listRecords"

    public struct Record: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.repo.listRecords#record"
        public let uri: ATProtocolURI
        public let cid: CID
        public let value: ATProtocolValueContainer

        /// Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, value: ATProtocolValueContainer
        ) {
            self.uri = uri
            self.cid = cid
            self.value = value
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")

                throw error
            }
            do {
                value = try container.decode(ATProtocolValueContainer.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for required property 'value': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            try container.encode(value, forKey: .value)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if uri != other.uri {
                return false
            }

            if cid != other.cid {
                return false
            }

            if value != other.value {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)

            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case value
        }
    }

    public struct Parameters: Parametrizable {
        public let repo: ATIdentifier
        public let collection: NSID
        public let limit: Int?
        public let cursor: String?
        public let reverse: Bool?

        public init(
            repo: ATIdentifier,
            collection: NSID,
            limit: Int? = nil,
            cursor: String? = nil,
            reverse: Bool? = nil
        ) {
            self.repo = repo
            self.collection = collection
            self.limit = limit
            self.cursor = cursor
            self.reverse = reverse
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let records: [Record]

        /// Standard public initializer
        public init(
            cursor: String? = nil,

            records: [Record]

        ) {
            self.cursor = cursor

            self.records = records
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            records = try container.decode([Record].self, forKey: .records)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(records, forKey: .records)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let recordsValue = try records.toCBORValue()
            map = map.adding(key: "records", value: recordsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case records
        }
    }
}

public extension ATProtoClient.Com.Atproto.Repo {
    // MARK: - listRecords

    /// List a range of records in a repository, matching a specific collection. Does not require auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func listRecords(input: ComAtprotoRepoListRecords.Parameters) async throws -> (responseCode: Int, data: ComAtprotoRepoListRecords.Output?) {
        let endpoint = "com.atproto.repo.listRecords"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.repo.listRecords")
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
                let decodedData = try decoder.decode(ComAtprotoRepoListRecords.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.repo.listRecords: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
