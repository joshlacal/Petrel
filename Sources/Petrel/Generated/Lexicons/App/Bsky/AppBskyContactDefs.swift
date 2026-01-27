import Foundation

// lexicon: 1, id: app.bsky.contact.defs

public enum AppBskyContactDefs {
    public static let typeIdentifier = "app.bsky.contact.defs"

    public struct MatchAndContactIndex: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.contact.defs#matchAndContactIndex"
        public let match: AppBskyActorDefs.ProfileView
        public let contactIndex: Int

        /// Standard initializer
        public init(
            match: AppBskyActorDefs.ProfileView, contactIndex: Int
        ) {
            self.match = match
            self.contactIndex = contactIndex
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                match = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .match)

            } catch {
                LogManager.logError("Decoding error for required property 'match': \(error)")

                throw error
            }
            do {
                contactIndex = try container.decode(Int.self, forKey: .contactIndex)

            } catch {
                LogManager.logError("Decoding error for required property 'contactIndex': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(match, forKey: .match)

            try container.encode(contactIndex, forKey: .contactIndex)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(match)
            hasher.combine(contactIndex)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if match != other.match {
                return false
            }

            if contactIndex != other.contactIndex {
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

            let matchValue = try match.toCBORValue()
            map = map.adding(key: "match", value: matchValue)

            let contactIndexValue = try contactIndex.toCBORValue()
            map = map.adding(key: "contactIndex", value: contactIndexValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case match
            case contactIndex
        }
    }

    public struct SyncStatus: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.contact.defs#syncStatus"
        public let syncedAt: ATProtocolDate
        public let matchesCount: Int

        /// Standard initializer
        public init(
            syncedAt: ATProtocolDate, matchesCount: Int
        ) {
            self.syncedAt = syncedAt
            self.matchesCount = matchesCount
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                syncedAt = try container.decode(ATProtocolDate.self, forKey: .syncedAt)

            } catch {
                LogManager.logError("Decoding error for required property 'syncedAt': \(error)")

                throw error
            }
            do {
                matchesCount = try container.decode(Int.self, forKey: .matchesCount)

            } catch {
                LogManager.logError("Decoding error for required property 'matchesCount': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(syncedAt, forKey: .syncedAt)

            try container.encode(matchesCount, forKey: .matchesCount)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(syncedAt)
            hasher.combine(matchesCount)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if syncedAt != other.syncedAt {
                return false
            }

            if matchesCount != other.matchesCount {
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

            let syncedAtValue = try syncedAt.toCBORValue()
            map = map.adding(key: "syncedAt", value: syncedAtValue)

            let matchesCountValue = try matchesCount.toCBORValue()
            map = map.adding(key: "matchesCount", value: matchesCountValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case syncedAt
            case matchesCount
        }
    }

    public struct Notification: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.contact.defs#notification"
        public let from: DID
        public let to: DID

        /// Standard initializer
        public init(
            from: DID, to: DID
        ) {
            self.from = from
            self.to = to
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                from = try container.decode(DID.self, forKey: .from)

            } catch {
                LogManager.logError("Decoding error for required property 'from': \(error)")

                throw error
            }
            do {
                to = try container.decode(DID.self, forKey: .to)

            } catch {
                LogManager.logError("Decoding error for required property 'to': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(from, forKey: .from)

            try container.encode(to, forKey: .to)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(from)
            hasher.combine(to)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if from != other.from {
                return false
            }

            if to != other.to {
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

            let fromValue = try from.toCBORValue()
            map = map.adding(key: "from", value: fromValue)

            let toValue = try to.toCBORValue()
            map = map.adding(key: "to", value: toValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case from
            case to
        }
    }
}
