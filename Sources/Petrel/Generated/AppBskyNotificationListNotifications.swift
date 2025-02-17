import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.notification.listNotifications

public enum AppBskyNotificationListNotifications {
    public static let typeIdentifier = "app.bsky.notification.listNotifications"

    public struct Notification: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.notification.listNotifications#notification"
        public let uri: ATProtocolURI
        public let cid: String
        public let author: AppBskyActorDefs.ProfileView
        public let reason: String
        public let reasonSubject: ATProtocolURI?
        public let record: ATProtocolValueContainer
        public let isRead: Bool
        public let indexedAt: ATProtocolDate
        public let labels: [ComAtprotoLabelDefs.Label]?

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: String, author: AppBskyActorDefs.ProfileView, reason: String, reasonSubject: ATProtocolURI?, record: ATProtocolValueContainer, isRead: Bool, indexedAt: ATProtocolDate, labels: [ComAtprotoLabelDefs.Label]?
        ) {
            self.uri = uri
            self.cid = cid
            self.author = author
            self.reason = reason
            self.reasonSubject = reasonSubject
            self.record = record
            self.isRead = isRead
            self.indexedAt = indexedAt
            self.labels = labels
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                cid = try container.decode(String.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                author = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .author)

            } catch {
                LogManager.logError("Decoding error for property 'author': \(error)")
                throw error
            }
            do {
                reason = try container.decode(String.self, forKey: .reason)

            } catch {
                LogManager.logError("Decoding error for property 'reason': \(error)")
                throw error
            }
            do {
                reasonSubject = try container.decodeIfPresent(ATProtocolURI.self, forKey: .reasonSubject)

            } catch {
                LogManager.logError("Decoding error for property 'reasonSubject': \(error)")
                throw error
            }
            do {
                record = try container.decode(ATProtocolValueContainer.self, forKey: .record)

            } catch {
                LogManager.logError("Decoding error for property 'record': \(error)")
                throw error
            }
            do {
                isRead = try container.decode(Bool.self, forKey: .isRead)

            } catch {
                LogManager.logError("Decoding error for property 'isRead': \(error)")
                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            try container.encode(author, forKey: .author)

            try container.encode(reason, forKey: .reason)

            if let value = reasonSubject {
                try container.encode(value, forKey: .reasonSubject)
            }

            try container.encode(record, forKey: .record)

            try container.encode(isRead, forKey: .isRead)

            try container.encode(indexedAt, forKey: .indexedAt)

            if let value = labels {
                try container.encode(value, forKey: .labels)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(author)
            hasher.combine(reason)
            if let value = reasonSubject {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(record)
            hasher.combine(isRead)
            hasher.combine(indexedAt)
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if uri != other.uri {
                return false
            }

            if cid != other.cid {
                return false
            }

            if author != other.author {
                return false
            }

            if reason != other.reason {
                return false
            }

            if reasonSubject != other.reasonSubject {
                return false
            }

            if record != other.record {
                return false
            }

            if isRead != other.isRead {
                return false
            }

            if indexedAt != other.indexedAt {
                return false
            }

            if labels != other.labels {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case author
            case reason
            case reasonSubject
            case record
            case isRead
            case indexedAt
            case labels
        }
    }

    public struct Parameters: Parametrizable {
        public let reasons: [String]?
        public let limit: Int?
        public let priority: Bool?
        public let cursor: String?
        public let seenAt: ATProtocolDate?

        public init(
            reasons: [String]? = nil,
            limit: Int? = nil,
            priority: Bool? = nil,
            cursor: String? = nil,
            seenAt: ATProtocolDate? = nil
        ) {
            self.reasons = reasons
            self.limit = limit
            self.priority = priority
            self.cursor = cursor
            self.seenAt = seenAt
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let notifications: [Notification]

        public let priority: Bool?

        public let seenAt: ATProtocolDate?

        // Standard public initializer
        public init(
            cursor: String? = nil,

            notifications: [Notification],

            priority: Bool? = nil,

            seenAt: ATProtocolDate? = nil

        ) {
            self.cursor = cursor

            self.notifications = notifications

            self.priority = priority

            self.seenAt = seenAt
        }
    }
}

public extension ATProtoClient.App.Bsky.Notification {
    /// Enumerate notifications for the requesting account. Requires auth.
    func listNotifications(input: AppBskyNotificationListNotifications.Parameters) async throws -> (responseCode: Int, data: AppBskyNotificationListNotifications.Output?) {
        let endpoint = "app.bsky.notification.listNotifications"

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
        let decodedData = try? decoder.decode(AppBskyNotificationListNotifications.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
