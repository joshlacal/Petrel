import Foundation

// lexicon: 1, id: blue.catbird.mls.checkBlocks

public enum BlueCatbirdMlsCheckBlocks {
    public static let typeIdentifier = "blue.catbird.mls.checkBlocks"

    public struct BlockRelationship: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.checkBlocks#blockRelationship"
        public let blockerDid: DID
        public let blockedDid: DID
        public let createdAt: ATProtocolDate
        public let blockUri: ATProtocolURI?

        public init(
            blockerDid: DID, blockedDid: DID, createdAt: ATProtocolDate, blockUri: ATProtocolURI?
        ) {
            self.blockerDid = blockerDid
            self.blockedDid = blockedDid
            self.createdAt = createdAt
            self.blockUri = blockUri
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                blockerDid = try container.decode(DID.self, forKey: .blockerDid)
            } catch {
                LogManager.logError("Decoding error for required property 'blockerDid': \(error)")
                throw error
            }
            do {
                blockedDid = try container.decode(DID.self, forKey: .blockedDid)
            } catch {
                LogManager.logError("Decoding error for required property 'blockedDid': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                blockUri = try container.decodeIfPresent(ATProtocolURI.self, forKey: .blockUri)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'blockUri': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(blockerDid, forKey: .blockerDid)
            try container.encode(blockedDid, forKey: .blockedDid)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(blockUri, forKey: .blockUri)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(blockerDid)
            hasher.combine(blockedDid)
            hasher.combine(createdAt)
            if let value = blockUri {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if blockerDid != other.blockerDid {
                return false
            }
            if blockedDid != other.blockedDid {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if blockUri != other.blockUri {
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
            let blockerDidValue = try blockerDid.toCBORValue()
            map = map.adding(key: "blockerDid", value: blockerDidValue)
            let blockedDidValue = try blockedDid.toCBORValue()
            map = map.adding(key: "blockedDid", value: blockedDidValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = blockUri {
                let blockUriValue = try value.toCBORValue()
                map = map.adding(key: "blockUri", value: blockUriValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case blockerDid
            case blockedDid
            case createdAt
            case blockUri
        }
    }

    public struct Parameters: Parametrizable {
        public let dids: [DID]

        public init(
            dids: [DID]
        ) {
            self.dids = dids
        }
    }

    public struct Output: ATProtocolCodable {
        public let blocks: [BlockRelationship]

        public let checkedAt: ATProtocolDate

        /// Standard public initializer
        public init(
            blocks: [BlockRelationship],

            checkedAt: ATProtocolDate

        ) {
            self.blocks = blocks

            self.checkedAt = checkedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            blocks = try container.decode([BlockRelationship].self, forKey: .blocks)

            checkedAt = try container.decode(ATProtocolDate.self, forKey: .checkedAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(blocks, forKey: .blocks)

            try container.encode(checkedAt, forKey: .checkedAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let blocksValue = try blocks.toCBORValue()
            map = map.adding(key: "blocks", value: blocksValue)

            let checkedAtValue = try checkedAt.toCBORValue()
            map = map.adding(key: "checkedAt", value: checkedAtValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case blocks
            case checkedAt
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case tooManyDids = "TooManyDids.Too many DIDs provided (max 100)"
        case blueskyServiceUnavailable = "BlueskyServiceUnavailable.Could not reach Bluesky service to check blocks"
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
    // MARK: - checkBlocks

    /// Check Bluesky block relationships between users for MLS conversation moderation Query Bluesky social graph to check block status between users. Returns block relationships relevant to MLS conversation membership. Server queries Bluesky PDS for current block state. Used before adding members to prevent blocked users from joining the same conversation.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func checkBlocks(input: BlueCatbirdMlsCheckBlocks.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsCheckBlocks.Output?) {
        let endpoint = "blue.catbird.mls.checkBlocks"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.checkBlocks")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsCheckBlocks.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.checkBlocks: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
