import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.sync.listRepos

public enum ComAtprotoSyncListRepos {
    public static let typeIdentifier = "com.atproto.sync.listRepos"

    public struct Repo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.sync.listRepos#repo"
        public let did: String
        public let head: String
        public let rev: String
        public let active: Bool?
        public let status: String?

        // Standard initializer
        public init(
            did: String, head: String, rev: String, active: Bool?, status: String?
        ) {
            self.did = did
            self.head = head
            self.rev = rev
            self.active = active
            self.status = status
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(String.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                head = try container.decode(String.self, forKey: .head)

            } catch {
                LogManager.logError("Decoding error for property 'head': \(error)")
                throw error
            }
            do {
                rev = try container.decode(String.self, forKey: .rev)

            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                active = try container.decodeIfPresent(Bool.self, forKey: .active)

            } catch {
                LogManager.logError("Decoding error for property 'active': \(error)")
                throw error
            }
            do {
                status = try container.decodeIfPresent(String.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)

            try container.encode(head, forKey: .head)

            try container.encode(rev, forKey: .rev)

            if let value = active {
                try container.encode(value, forKey: .active)
            }

            if let value = status {
                try container.encode(value, forKey: .status)
            }
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

        // Standard public initializer
        public init(
            cursor: String? = nil,

            repos: [Repo]

        ) {
            self.cursor = cursor

            self.repos = repos
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    /// Enumerates all the DID, rev, and commit CID for all repos hosted by this service. Does not require auth; implemented by PDS and Relay.
    func listRepos(input: ComAtprotoSyncListRepos.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncListRepos.Output?) {
        let endpoint = "com.atproto.sync.listRepos"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoSyncListRepos.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
