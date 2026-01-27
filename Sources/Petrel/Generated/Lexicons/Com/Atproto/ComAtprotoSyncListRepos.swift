import Foundation

// lexicon: 1, id: com.atproto.sync.listRepos

public enum ComAtprotoSyncListRepos {
    public static let typeIdentifier = "com.atproto.sync.listRepos"

    public struct Repo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.sync.listRepos#repo"
        public let did: DID
        public let head: CID
        public let rev: TID
        public let active: Bool?
        public let status: String?

        public init(
            did: DID, head: CID, rev: TID, active: Bool?, status: String?
        ) {
            self.did = did
            self.head = head
            self.rev = rev
            self.active = active
            self.status = status
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
                throw error
            }
            do {
                head = try container.decode(CID.self, forKey: .head)
            } catch {
                LogManager.logError("Decoding error for required property 'head': \(error)")
                throw error
            }
            do {
                rev = try container.decode(TID.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                active = try container.decodeIfPresent(Bool.self, forKey: .active)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'active': \(error)")
                throw error
            }
            do {
                status = try container.decodeIfPresent(String.self, forKey: .status)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'status': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(head, forKey: .head)
            try container.encode(rev, forKey: .rev)
            try container.encodeIfPresent(active, forKey: .active)
            try container.encodeIfPresent(status, forKey: .status)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(head)
            hasher.combine(rev)
            if let value = active {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = status {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if did != other.did {
                return false
            }
            if head != other.head {
                return false
            }
            if rev != other.rev {
                return false
            }
            if active != other.active {
                return false
            }
            if status != other.status {
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
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            let headValue = try head.toCBORValue()
            map = map.adding(key: "head", value: headValue)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            if let value = active {
                let activeValue = try value.toCBORValue()
                map = map.adding(key: "active", value: activeValue)
            }
            if let value = status {
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case head
            case rev
            case active
            case status
        }
    }

    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let repos: [Repo]

        /// Standard public initializer
        public init(
            cursor: String? = nil,

            repos: [Repo]

        ) {
            self.cursor = cursor

            self.repos = repos
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            repos = try container.decode([Repo].self, forKey: .repos)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(repos, forKey: .repos)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let reposValue = try repos.toCBORValue()
            map = map.adding(key: "repos", value: reposValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case repos
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    // MARK: - listRepos

    /// Enumerates all the DID, rev, and commit CID for all repos hosted by this service. Does not require auth; implemented by PDS and Relay.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func listRepos(input: ComAtprotoSyncListRepos.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncListRepos.Output?) {
        let endpoint = "com.atproto.sync.listRepos"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.sync.listRepos")
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
                let decodedData = try decoder.decode(ComAtprotoSyncListRepos.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.sync.listRepos: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
