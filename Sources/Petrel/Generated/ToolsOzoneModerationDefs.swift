import Foundation

// lexicon: 1, id: tools.ozone.moderation.defs

public enum ToolsOzoneModerationDefs {
    public static let typeIdentifier = "tools.ozone.moderation.defs"

    public struct ModEventView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventView"
        public let id: Int
        public let event: ModEventViewEventUnion
        public let subject: ModEventViewSubjectUnion
        public let subjectBlobCids: [String]
        public let createdBy: DID
        public let createdAt: ATProtocolDate
        public let creatorHandle: String?
        public let subjectHandle: String?

        // Standard initializer
        public init(
            id: Int, event: ModEventViewEventUnion, subject: ModEventViewSubjectUnion, subjectBlobCids: [String], createdBy: DID, createdAt: ATProtocolDate, creatorHandle: String?, subjectHandle: String?
        ) {
            self.id = id
            self.event = event
            self.subject = subject
            self.subjectBlobCids = subjectBlobCids
            self.createdBy = createdBy
            self.createdAt = createdAt
            self.creatorHandle = creatorHandle
            self.subjectHandle = subjectHandle
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(Int.self, forKey: .id)

            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                event = try container.decode(ModEventViewEventUnion.self, forKey: .event)

            } catch {
                LogManager.logError("Decoding error for property 'event': \(error)")
                throw error
            }
            do {
                subject = try container.decode(ModEventViewSubjectUnion.self, forKey: .subject)

            } catch {
                LogManager.logError("Decoding error for property 'subject': \(error)")
                throw error
            }
            do {
                subjectBlobCids = try container.decode([String].self, forKey: .subjectBlobCids)

            } catch {
                LogManager.logError("Decoding error for property 'subjectBlobCids': \(error)")
                throw error
            }
            do {
                createdBy = try container.decode(DID.self, forKey: .createdBy)

            } catch {
                LogManager.logError("Decoding error for property 'createdBy': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                creatorHandle = try container.decodeIfPresent(String.self, forKey: .creatorHandle)

            } catch {
                LogManager.logError("Decoding error for property 'creatorHandle': \(error)")
                throw error
            }
            do {
                subjectHandle = try container.decodeIfPresent(String.self, forKey: .subjectHandle)

            } catch {
                LogManager.logError("Decoding error for property 'subjectHandle': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(id, forKey: .id)

            try container.encode(event, forKey: .event)

            try container.encode(subject, forKey: .subject)

            try container.encode(subjectBlobCids, forKey: .subjectBlobCids)

            try container.encode(createdBy, forKey: .createdBy)

            try container.encode(createdAt, forKey: .createdAt)

            if let value = creatorHandle {
                try container.encode(value, forKey: .creatorHandle)
            }

            if let value = subjectHandle {
                try container.encode(value, forKey: .subjectHandle)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(event)
            hasher.combine(subject)
            hasher.combine(subjectBlobCids)
            hasher.combine(createdBy)
            hasher.combine(createdAt)
            if let value = creatorHandle {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = subjectHandle {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if id != other.id {
                return false
            }

            if event != other.event {
                return false
            }

            if subject != other.subject {
                return false
            }

            if subjectBlobCids != other.subjectBlobCids {
                return false
            }

            if createdBy != other.createdBy {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if creatorHandle != other.creatorHandle {
                return false
            }

            if subjectHandle != other.subjectHandle {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let idValue = try (id as? DAGCBOREncodable)?.toCBORValue() ?? id
            map = map.adding(key: "id", value: idValue)

            let eventValue = try (event as? DAGCBOREncodable)?.toCBORValue() ?? event
            map = map.adding(key: "event", value: eventValue)

            let subjectValue = try (subject as? DAGCBOREncodable)?.toCBORValue() ?? subject
            map = map.adding(key: "subject", value: subjectValue)

            let subjectBlobCidsValue = try (subjectBlobCids as? DAGCBOREncodable)?.toCBORValue() ?? subjectBlobCids
            map = map.adding(key: "subjectBlobCids", value: subjectBlobCidsValue)

            let createdByValue = try (createdBy as? DAGCBOREncodable)?.toCBORValue() ?? createdBy
            map = map.adding(key: "createdBy", value: createdByValue)

            let createdAtValue = try (createdAt as? DAGCBOREncodable)?.toCBORValue() ?? createdAt
            map = map.adding(key: "createdAt", value: createdAtValue)

            if let value = creatorHandle {
                let creatorHandleValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "creatorHandle", value: creatorHandleValue)
            }

            if let value = subjectHandle {
                let subjectHandleValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "subjectHandle", value: subjectHandleValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case event
            case subject
            case subjectBlobCids
            case createdBy
            case createdAt
            case creatorHandle
            case subjectHandle
        }
    }

    public struct ModEventViewDetail: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventViewDetail"
        public let id: Int
        public let event: ModEventViewDetailEventUnion
        public let subject: ModEventViewDetailSubjectUnion
        public let subjectBlobs: [BlobView]
        public let createdBy: DID
        public let createdAt: ATProtocolDate

        // Standard initializer
        public init(
            id: Int, event: ModEventViewDetailEventUnion, subject: ModEventViewDetailSubjectUnion, subjectBlobs: [BlobView], createdBy: DID, createdAt: ATProtocolDate
        ) {
            self.id = id
            self.event = event
            self.subject = subject
            self.subjectBlobs = subjectBlobs
            self.createdBy = createdBy
            self.createdAt = createdAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(Int.self, forKey: .id)

            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                event = try container.decode(ModEventViewDetailEventUnion.self, forKey: .event)

            } catch {
                LogManager.logError("Decoding error for property 'event': \(error)")
                throw error
            }
            do {
                subject = try container.decode(ModEventViewDetailSubjectUnion.self, forKey: .subject)

            } catch {
                LogManager.logError("Decoding error for property 'subject': \(error)")
                throw error
            }
            do {
                subjectBlobs = try container.decode([BlobView].self, forKey: .subjectBlobs)

            } catch {
                LogManager.logError("Decoding error for property 'subjectBlobs': \(error)")
                throw error
            }
            do {
                createdBy = try container.decode(DID.self, forKey: .createdBy)

            } catch {
                LogManager.logError("Decoding error for property 'createdBy': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(id, forKey: .id)

            try container.encode(event, forKey: .event)

            try container.encode(subject, forKey: .subject)

            try container.encode(subjectBlobs, forKey: .subjectBlobs)

            try container.encode(createdBy, forKey: .createdBy)

            try container.encode(createdAt, forKey: .createdAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(event)
            hasher.combine(subject)
            hasher.combine(subjectBlobs)
            hasher.combine(createdBy)
            hasher.combine(createdAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if id != other.id {
                return false
            }

            if event != other.event {
                return false
            }

            if subject != other.subject {
                return false
            }

            if subjectBlobs != other.subjectBlobs {
                return false
            }

            if createdBy != other.createdBy {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let idValue = try (id as? DAGCBOREncodable)?.toCBORValue() ?? id
            map = map.adding(key: "id", value: idValue)

            let eventValue = try (event as? DAGCBOREncodable)?.toCBORValue() ?? event
            map = map.adding(key: "event", value: eventValue)

            let subjectValue = try (subject as? DAGCBOREncodable)?.toCBORValue() ?? subject
            map = map.adding(key: "subject", value: subjectValue)

            let subjectBlobsValue = try (subjectBlobs as? DAGCBOREncodable)?.toCBORValue() ?? subjectBlobs
            map = map.adding(key: "subjectBlobs", value: subjectBlobsValue)

            let createdByValue = try (createdBy as? DAGCBOREncodable)?.toCBORValue() ?? createdBy
            map = map.adding(key: "createdBy", value: createdByValue)

            let createdAtValue = try (createdAt as? DAGCBOREncodable)?.toCBORValue() ?? createdAt
            map = map.adding(key: "createdAt", value: createdAtValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case event
            case subject
            case subjectBlobs
            case createdBy
            case createdAt
        }
    }

    public struct SubjectStatusView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#subjectStatusView"
        public let id: Int
        public let subject: SubjectStatusViewSubjectUnion
        public let hosting: SubjectStatusViewHostingUnion?
        public let subjectBlobCids: [CID]?
        public let subjectRepoHandle: String?
        public let updatedAt: ATProtocolDate
        public let createdAt: ATProtocolDate
        public let reviewState: SubjectReviewState
        public let comment: String?
        public let priorityScore: Int?
        public let muteUntil: ATProtocolDate?
        public let muteReportingUntil: ATProtocolDate?
        public let lastReviewedBy: DID?
        public let lastReviewedAt: ATProtocolDate?
        public let lastReportedAt: ATProtocolDate?
        public let lastAppealedAt: ATProtocolDate?
        public let takendown: Bool?
        public let appealed: Bool?
        public let suspendUntil: ATProtocolDate?
        public let tags: [String]?
        public let accountStats: AccountStats?
        public let recordsStats: RecordsStats?

        // Standard initializer
        public init(
            id: Int, subject: SubjectStatusViewSubjectUnion, hosting: SubjectStatusViewHostingUnion?, subjectBlobCids: [CID]?, subjectRepoHandle: String?, updatedAt: ATProtocolDate, createdAt: ATProtocolDate, reviewState: SubjectReviewState, comment: String?, priorityScore: Int?, muteUntil: ATProtocolDate?, muteReportingUntil: ATProtocolDate?, lastReviewedBy: DID?, lastReviewedAt: ATProtocolDate?, lastReportedAt: ATProtocolDate?, lastAppealedAt: ATProtocolDate?, takendown: Bool?, appealed: Bool?, suspendUntil: ATProtocolDate?, tags: [String]?, accountStats: AccountStats?, recordsStats: RecordsStats?
        ) {
            self.id = id
            self.subject = subject
            self.hosting = hosting
            self.subjectBlobCids = subjectBlobCids
            self.subjectRepoHandle = subjectRepoHandle
            self.updatedAt = updatedAt
            self.createdAt = createdAt
            self.reviewState = reviewState
            self.comment = comment
            self.priorityScore = priorityScore
            self.muteUntil = muteUntil
            self.muteReportingUntil = muteReportingUntil
            self.lastReviewedBy = lastReviewedBy
            self.lastReviewedAt = lastReviewedAt
            self.lastReportedAt = lastReportedAt
            self.lastAppealedAt = lastAppealedAt
            self.takendown = takendown
            self.appealed = appealed
            self.suspendUntil = suspendUntil
            self.tags = tags
            self.accountStats = accountStats
            self.recordsStats = recordsStats
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(Int.self, forKey: .id)

            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                subject = try container.decode(SubjectStatusViewSubjectUnion.self, forKey: .subject)

            } catch {
                LogManager.logError("Decoding error for property 'subject': \(error)")
                throw error
            }
            do {
                hosting = try container.decodeIfPresent(SubjectStatusViewHostingUnion.self, forKey: .hosting)

            } catch {
                LogManager.logError("Decoding error for property 'hosting': \(error)")
                throw error
            }
            do {
                subjectBlobCids = try container.decodeIfPresent([CID].self, forKey: .subjectBlobCids)

            } catch {
                LogManager.logError("Decoding error for property 'subjectBlobCids': \(error)")
                throw error
            }
            do {
                subjectRepoHandle = try container.decodeIfPresent(String.self, forKey: .subjectRepoHandle)

            } catch {
                LogManager.logError("Decoding error for property 'subjectRepoHandle': \(error)")
                throw error
            }
            do {
                updatedAt = try container.decode(ATProtocolDate.self, forKey: .updatedAt)

            } catch {
                LogManager.logError("Decoding error for property 'updatedAt': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                reviewState = try container.decode(SubjectReviewState.self, forKey: .reviewState)

            } catch {
                LogManager.logError("Decoding error for property 'reviewState': \(error)")
                throw error
            }
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                priorityScore = try container.decodeIfPresent(Int.self, forKey: .priorityScore)

            } catch {
                LogManager.logError("Decoding error for property 'priorityScore': \(error)")
                throw error
            }
            do {
                muteUntil = try container.decodeIfPresent(ATProtocolDate.self, forKey: .muteUntil)

            } catch {
                LogManager.logError("Decoding error for property 'muteUntil': \(error)")
                throw error
            }
            do {
                muteReportingUntil = try container.decodeIfPresent(ATProtocolDate.self, forKey: .muteReportingUntil)

            } catch {
                LogManager.logError("Decoding error for property 'muteReportingUntil': \(error)")
                throw error
            }
            do {
                lastReviewedBy = try container.decodeIfPresent(DID.self, forKey: .lastReviewedBy)

            } catch {
                LogManager.logError("Decoding error for property 'lastReviewedBy': \(error)")
                throw error
            }
            do {
                lastReviewedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastReviewedAt)

            } catch {
                LogManager.logError("Decoding error for property 'lastReviewedAt': \(error)")
                throw error
            }
            do {
                lastReportedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastReportedAt)

            } catch {
                LogManager.logError("Decoding error for property 'lastReportedAt': \(error)")
                throw error
            }
            do {
                lastAppealedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastAppealedAt)

            } catch {
                LogManager.logError("Decoding error for property 'lastAppealedAt': \(error)")
                throw error
            }
            do {
                takendown = try container.decodeIfPresent(Bool.self, forKey: .takendown)

            } catch {
                LogManager.logError("Decoding error for property 'takendown': \(error)")
                throw error
            }
            do {
                appealed = try container.decodeIfPresent(Bool.self, forKey: .appealed)

            } catch {
                LogManager.logError("Decoding error for property 'appealed': \(error)")
                throw error
            }
            do {
                suspendUntil = try container.decodeIfPresent(ATProtocolDate.self, forKey: .suspendUntil)

            } catch {
                LogManager.logError("Decoding error for property 'suspendUntil': \(error)")
                throw error
            }
            do {
                tags = try container.decodeIfPresent([String].self, forKey: .tags)

            } catch {
                LogManager.logError("Decoding error for property 'tags': \(error)")
                throw error
            }
            do {
                accountStats = try container.decodeIfPresent(AccountStats.self, forKey: .accountStats)

            } catch {
                LogManager.logError("Decoding error for property 'accountStats': \(error)")
                throw error
            }
            do {
                recordsStats = try container.decodeIfPresent(RecordsStats.self, forKey: .recordsStats)

            } catch {
                LogManager.logError("Decoding error for property 'recordsStats': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(id, forKey: .id)

            try container.encode(subject, forKey: .subject)

            if let value = hosting {
                try container.encode(value, forKey: .hosting)
            }

            if let value = subjectBlobCids {
                if !value.isEmpty {
                    try container.encode(value, forKey: .subjectBlobCids)
                }
            }

            if let value = subjectRepoHandle {
                try container.encode(value, forKey: .subjectRepoHandle)
            }

            try container.encode(updatedAt, forKey: .updatedAt)

            try container.encode(createdAt, forKey: .createdAt)

            try container.encode(reviewState, forKey: .reviewState)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            if let value = priorityScore {
                try container.encode(value, forKey: .priorityScore)
            }

            if let value = muteUntil {
                try container.encode(value, forKey: .muteUntil)
            }

            if let value = muteReportingUntil {
                try container.encode(value, forKey: .muteReportingUntil)
            }

            if let value = lastReviewedBy {
                try container.encode(value, forKey: .lastReviewedBy)
            }

            if let value = lastReviewedAt {
                try container.encode(value, forKey: .lastReviewedAt)
            }

            if let value = lastReportedAt {
                try container.encode(value, forKey: .lastReportedAt)
            }

            if let value = lastAppealedAt {
                try container.encode(value, forKey: .lastAppealedAt)
            }

            if let value = takendown {
                try container.encode(value, forKey: .takendown)
            }

            if let value = appealed {
                try container.encode(value, forKey: .appealed)
            }

            if let value = suspendUntil {
                try container.encode(value, forKey: .suspendUntil)
            }

            if let value = tags {
                if !value.isEmpty {
                    try container.encode(value, forKey: .tags)
                }
            }

            if let value = accountStats {
                try container.encode(value, forKey: .accountStats)
            }

            if let value = recordsStats {
                try container.encode(value, forKey: .recordsStats)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(subject)
            if let value = hosting {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = subjectBlobCids {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = subjectRepoHandle {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(updatedAt)
            hasher.combine(createdAt)
            hasher.combine(reviewState)
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = priorityScore {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = muteUntil {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = muteReportingUntil {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = lastReviewedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = lastReviewedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = lastReportedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = lastAppealedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = takendown {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = appealed {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = suspendUntil {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = tags {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = accountStats {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = recordsStats {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if id != other.id {
                return false
            }

            if subject != other.subject {
                return false
            }

            if hosting != other.hosting {
                return false
            }

            if subjectBlobCids != other.subjectBlobCids {
                return false
            }

            if subjectRepoHandle != other.subjectRepoHandle {
                return false
            }

            if updatedAt != other.updatedAt {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if reviewState != other.reviewState {
                return false
            }

            if comment != other.comment {
                return false
            }

            if priorityScore != other.priorityScore {
                return false
            }

            if muteUntil != other.muteUntil {
                return false
            }

            if muteReportingUntil != other.muteReportingUntil {
                return false
            }

            if lastReviewedBy != other.lastReviewedBy {
                return false
            }

            if lastReviewedAt != other.lastReviewedAt {
                return false
            }

            if lastReportedAt != other.lastReportedAt {
                return false
            }

            if lastAppealedAt != other.lastAppealedAt {
                return false
            }

            if takendown != other.takendown {
                return false
            }

            if appealed != other.appealed {
                return false
            }

            if suspendUntil != other.suspendUntil {
                return false
            }

            if tags != other.tags {
                return false
            }

            if accountStats != other.accountStats {
                return false
            }

            if recordsStats != other.recordsStats {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let idValue = try (id as? DAGCBOREncodable)?.toCBORValue() ?? id
            map = map.adding(key: "id", value: idValue)

            let subjectValue = try (subject as? DAGCBOREncodable)?.toCBORValue() ?? subject
            map = map.adding(key: "subject", value: subjectValue)

            if let value = hosting {
                let hostingValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "hosting", value: hostingValue)
            }

            if let value = subjectBlobCids {
                if !value.isEmpty {
                    let subjectBlobCidsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "subjectBlobCids", value: subjectBlobCidsValue)
                }
            }

            if let value = subjectRepoHandle {
                let subjectRepoHandleValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "subjectRepoHandle", value: subjectRepoHandleValue)
            }

            let updatedAtValue = try (updatedAt as? DAGCBOREncodable)?.toCBORValue() ?? updatedAt
            map = map.adding(key: "updatedAt", value: updatedAtValue)

            let createdAtValue = try (createdAt as? DAGCBOREncodable)?.toCBORValue() ?? createdAt
            map = map.adding(key: "createdAt", value: createdAtValue)

            let reviewStateValue = try (reviewState as? DAGCBOREncodable)?.toCBORValue() ?? reviewState
            map = map.adding(key: "reviewState", value: reviewStateValue)

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            if let value = priorityScore {
                let priorityScoreValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "priorityScore", value: priorityScoreValue)
            }

            if let value = muteUntil {
                let muteUntilValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "muteUntil", value: muteUntilValue)
            }

            if let value = muteReportingUntil {
                let muteReportingUntilValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "muteReportingUntil", value: muteReportingUntilValue)
            }

            if let value = lastReviewedBy {
                let lastReviewedByValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "lastReviewedBy", value: lastReviewedByValue)
            }

            if let value = lastReviewedAt {
                let lastReviewedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "lastReviewedAt", value: lastReviewedAtValue)
            }

            if let value = lastReportedAt {
                let lastReportedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "lastReportedAt", value: lastReportedAtValue)
            }

            if let value = lastAppealedAt {
                let lastAppealedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "lastAppealedAt", value: lastAppealedAtValue)
            }

            if let value = takendown {
                let takendownValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "takendown", value: takendownValue)
            }

            if let value = appealed {
                let appealedValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "appealed", value: appealedValue)
            }

            if let value = suspendUntil {
                let suspendUntilValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "suspendUntil", value: suspendUntilValue)
            }

            if let value = tags {
                if !value.isEmpty {
                    let tagsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "tags", value: tagsValue)
                }
            }

            if let value = accountStats {
                let accountStatsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "accountStats", value: accountStatsValue)
            }

            if let value = recordsStats {
                let recordsStatsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "recordsStats", value: recordsStatsValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case subject
            case hosting
            case subjectBlobCids
            case subjectRepoHandle
            case updatedAt
            case createdAt
            case reviewState
            case comment
            case priorityScore
            case muteUntil
            case muteReportingUntil
            case lastReviewedBy
            case lastReviewedAt
            case lastReportedAt
            case lastAppealedAt
            case takendown
            case appealed
            case suspendUntil
            case tags
            case accountStats
            case recordsStats
        }
    }

    public struct SubjectView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#subjectView"
        public let type: ComAtprotoModerationDefs.SubjectType
        public let subject: String
        public let status: SubjectStatusView?
        public let repo: RepoViewDetail?
        public let profile: SubjectViewProfileUnion?
        public let record: RecordViewDetail?

        // Standard initializer
        public init(
            type: ComAtprotoModerationDefs.SubjectType, subject: String, status: SubjectStatusView?, repo: RepoViewDetail?, profile: SubjectViewProfileUnion?, record: RecordViewDetail?
        ) {
            self.type = type
            self.subject = subject
            self.status = status
            self.repo = repo
            self.profile = profile
            self.record = record
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                type = try container.decode(ComAtprotoModerationDefs.SubjectType.self, forKey: .type)

            } catch {
                LogManager.logError("Decoding error for property 'type': \(error)")
                throw error
            }
            do {
                subject = try container.decode(String.self, forKey: .subject)

            } catch {
                LogManager.logError("Decoding error for property 'subject': \(error)")
                throw error
            }
            do {
                status = try container.decodeIfPresent(SubjectStatusView.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
                throw error
            }
            do {
                repo = try container.decodeIfPresent(RepoViewDetail.self, forKey: .repo)

            } catch {
                LogManager.logError("Decoding error for property 'repo': \(error)")
                throw error
            }
            do {
                profile = try container.decodeIfPresent(SubjectViewProfileUnion.self, forKey: .profile)

            } catch {
                LogManager.logError("Decoding error for property 'profile': \(error)")
                throw error
            }
            do {
                record = try container.decodeIfPresent(RecordViewDetail.self, forKey: .record)

            } catch {
                LogManager.logError("Decoding error for property 'record': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(type, forKey: .type)

            try container.encode(subject, forKey: .subject)

            if let value = status {
                try container.encode(value, forKey: .status)
            }

            if let value = repo {
                try container.encode(value, forKey: .repo)
            }

            if let value = profile {
                try container.encode(value, forKey: .profile)
            }

            if let value = record {
                try container.encode(value, forKey: .record)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(type)
            hasher.combine(subject)
            if let value = status {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = repo {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = profile {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = record {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if type != other.type {
                return false
            }

            if subject != other.subject {
                return false
            }

            if status != other.status {
                return false
            }

            if repo != other.repo {
                return false
            }

            if profile != other.profile {
                return false
            }

            if record != other.record {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let typeValue = try (type as? DAGCBOREncodable)?.toCBORValue() ?? type
            map = map.adding(key: "type", value: typeValue)

            let subjectValue = try (subject as? DAGCBOREncodable)?.toCBORValue() ?? subject
            map = map.adding(key: "subject", value: subjectValue)

            if let value = status {
                let statusValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "status", value: statusValue)
            }

            if let value = repo {
                let repoValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "repo", value: repoValue)
            }

            if let value = profile {
                let profileValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "profile", value: profileValue)
            }

            if let value = record {
                let recordValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "record", value: recordValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case type
            case subject
            case status
            case repo
            case profile
            case record
        }
    }

    public struct AccountStats: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#accountStats"
        public let reportCount: Int?
        public let appealCount: Int?
        public let suspendCount: Int?
        public let escalateCount: Int?
        public let takedownCount: Int?

        // Standard initializer
        public init(
            reportCount: Int?, appealCount: Int?, suspendCount: Int?, escalateCount: Int?, takedownCount: Int?
        ) {
            self.reportCount = reportCount
            self.appealCount = appealCount
            self.suspendCount = suspendCount
            self.escalateCount = escalateCount
            self.takedownCount = takedownCount
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                reportCount = try container.decodeIfPresent(Int.self, forKey: .reportCount)

            } catch {
                LogManager.logError("Decoding error for property 'reportCount': \(error)")
                throw error
            }
            do {
                appealCount = try container.decodeIfPresent(Int.self, forKey: .appealCount)

            } catch {
                LogManager.logError("Decoding error for property 'appealCount': \(error)")
                throw error
            }
            do {
                suspendCount = try container.decodeIfPresent(Int.self, forKey: .suspendCount)

            } catch {
                LogManager.logError("Decoding error for property 'suspendCount': \(error)")
                throw error
            }
            do {
                escalateCount = try container.decodeIfPresent(Int.self, forKey: .escalateCount)

            } catch {
                LogManager.logError("Decoding error for property 'escalateCount': \(error)")
                throw error
            }
            do {
                takedownCount = try container.decodeIfPresent(Int.self, forKey: .takedownCount)

            } catch {
                LogManager.logError("Decoding error for property 'takedownCount': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = reportCount {
                try container.encode(value, forKey: .reportCount)
            }

            if let value = appealCount {
                try container.encode(value, forKey: .appealCount)
            }

            if let value = suspendCount {
                try container.encode(value, forKey: .suspendCount)
            }

            if let value = escalateCount {
                try container.encode(value, forKey: .escalateCount)
            }

            if let value = takedownCount {
                try container.encode(value, forKey: .takedownCount)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = reportCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = appealCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = suspendCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = escalateCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = takedownCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if reportCount != other.reportCount {
                return false
            }

            if appealCount != other.appealCount {
                return false
            }

            if suspendCount != other.suspendCount {
                return false
            }

            if escalateCount != other.escalateCount {
                return false
            }

            if takedownCount != other.takedownCount {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = reportCount {
                let reportCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "reportCount", value: reportCountValue)
            }

            if let value = appealCount {
                let appealCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "appealCount", value: appealCountValue)
            }

            if let value = suspendCount {
                let suspendCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "suspendCount", value: suspendCountValue)
            }

            if let value = escalateCount {
                let escalateCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "escalateCount", value: escalateCountValue)
            }

            if let value = takedownCount {
                let takedownCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "takedownCount", value: takedownCountValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case reportCount
            case appealCount
            case suspendCount
            case escalateCount
            case takedownCount
        }
    }

    public struct RecordsStats: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#recordsStats"
        public let totalReports: Int?
        public let reportedCount: Int?
        public let escalatedCount: Int?
        public let appealedCount: Int?
        public let subjectCount: Int?
        public let pendingCount: Int?
        public let processedCount: Int?
        public let takendownCount: Int?

        // Standard initializer
        public init(
            totalReports: Int?, reportedCount: Int?, escalatedCount: Int?, appealedCount: Int?, subjectCount: Int?, pendingCount: Int?, processedCount: Int?, takendownCount: Int?
        ) {
            self.totalReports = totalReports
            self.reportedCount = reportedCount
            self.escalatedCount = escalatedCount
            self.appealedCount = appealedCount
            self.subjectCount = subjectCount
            self.pendingCount = pendingCount
            self.processedCount = processedCount
            self.takendownCount = takendownCount
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                totalReports = try container.decodeIfPresent(Int.self, forKey: .totalReports)

            } catch {
                LogManager.logError("Decoding error for property 'totalReports': \(error)")
                throw error
            }
            do {
                reportedCount = try container.decodeIfPresent(Int.self, forKey: .reportedCount)

            } catch {
                LogManager.logError("Decoding error for property 'reportedCount': \(error)")
                throw error
            }
            do {
                escalatedCount = try container.decodeIfPresent(Int.self, forKey: .escalatedCount)

            } catch {
                LogManager.logError("Decoding error for property 'escalatedCount': \(error)")
                throw error
            }
            do {
                appealedCount = try container.decodeIfPresent(Int.self, forKey: .appealedCount)

            } catch {
                LogManager.logError("Decoding error for property 'appealedCount': \(error)")
                throw error
            }
            do {
                subjectCount = try container.decodeIfPresent(Int.self, forKey: .subjectCount)

            } catch {
                LogManager.logError("Decoding error for property 'subjectCount': \(error)")
                throw error
            }
            do {
                pendingCount = try container.decodeIfPresent(Int.self, forKey: .pendingCount)

            } catch {
                LogManager.logError("Decoding error for property 'pendingCount': \(error)")
                throw error
            }
            do {
                processedCount = try container.decodeIfPresent(Int.self, forKey: .processedCount)

            } catch {
                LogManager.logError("Decoding error for property 'processedCount': \(error)")
                throw error
            }
            do {
                takendownCount = try container.decodeIfPresent(Int.self, forKey: .takendownCount)

            } catch {
                LogManager.logError("Decoding error for property 'takendownCount': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = totalReports {
                try container.encode(value, forKey: .totalReports)
            }

            if let value = reportedCount {
                try container.encode(value, forKey: .reportedCount)
            }

            if let value = escalatedCount {
                try container.encode(value, forKey: .escalatedCount)
            }

            if let value = appealedCount {
                try container.encode(value, forKey: .appealedCount)
            }

            if let value = subjectCount {
                try container.encode(value, forKey: .subjectCount)
            }

            if let value = pendingCount {
                try container.encode(value, forKey: .pendingCount)
            }

            if let value = processedCount {
                try container.encode(value, forKey: .processedCount)
            }

            if let value = takendownCount {
                try container.encode(value, forKey: .takendownCount)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = totalReports {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = reportedCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = escalatedCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = appealedCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = subjectCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = pendingCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = processedCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = takendownCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if totalReports != other.totalReports {
                return false
            }

            if reportedCount != other.reportedCount {
                return false
            }

            if escalatedCount != other.escalatedCount {
                return false
            }

            if appealedCount != other.appealedCount {
                return false
            }

            if subjectCount != other.subjectCount {
                return false
            }

            if pendingCount != other.pendingCount {
                return false
            }

            if processedCount != other.processedCount {
                return false
            }

            if takendownCount != other.takendownCount {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = totalReports {
                let totalReportsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "totalReports", value: totalReportsValue)
            }

            if let value = reportedCount {
                let reportedCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "reportedCount", value: reportedCountValue)
            }

            if let value = escalatedCount {
                let escalatedCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "escalatedCount", value: escalatedCountValue)
            }

            if let value = appealedCount {
                let appealedCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "appealedCount", value: appealedCountValue)
            }

            if let value = subjectCount {
                let subjectCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "subjectCount", value: subjectCountValue)
            }

            if let value = pendingCount {
                let pendingCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "pendingCount", value: pendingCountValue)
            }

            if let value = processedCount {
                let processedCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "processedCount", value: processedCountValue)
            }

            if let value = takendownCount {
                let takendownCountValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "takendownCount", value: takendownCountValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case totalReports
            case reportedCount
            case escalatedCount
            case appealedCount
            case subjectCount
            case pendingCount
            case processedCount
            case takendownCount
        }
    }

    public struct ModEventTakedown: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventTakedown"
        public let comment: String?
        public let durationInHours: Int?
        public let acknowledgeAccountSubjects: Bool?
        public let policies: [String]?

        // Standard initializer
        public init(
            comment: String?, durationInHours: Int?, acknowledgeAccountSubjects: Bool?, policies: [String]?
        ) {
            self.comment = comment
            self.durationInHours = durationInHours
            self.acknowledgeAccountSubjects = acknowledgeAccountSubjects
            self.policies = policies
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                durationInHours = try container.decodeIfPresent(Int.self, forKey: .durationInHours)

            } catch {
                LogManager.logError("Decoding error for property 'durationInHours': \(error)")
                throw error
            }
            do {
                acknowledgeAccountSubjects = try container.decodeIfPresent(Bool.self, forKey: .acknowledgeAccountSubjects)

            } catch {
                LogManager.logError("Decoding error for property 'acknowledgeAccountSubjects': \(error)")
                throw error
            }
            do {
                policies = try container.decodeIfPresent([String].self, forKey: .policies)

            } catch {
                LogManager.logError("Decoding error for property 'policies': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            if let value = durationInHours {
                try container.encode(value, forKey: .durationInHours)
            }

            if let value = acknowledgeAccountSubjects {
                try container.encode(value, forKey: .acknowledgeAccountSubjects)
            }

            if let value = policies {
                if !value.isEmpty {
                    try container.encode(value, forKey: .policies)
                }
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = durationInHours {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = acknowledgeAccountSubjects {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = policies {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            if durationInHours != other.durationInHours {
                return false
            }

            if acknowledgeAccountSubjects != other.acknowledgeAccountSubjects {
                return false
            }

            if policies != other.policies {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            if let value = durationInHours {
                let durationInHoursValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "durationInHours", value: durationInHoursValue)
            }

            if let value = acknowledgeAccountSubjects {
                let acknowledgeAccountSubjectsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "acknowledgeAccountSubjects", value: acknowledgeAccountSubjectsValue)
            }

            if let value = policies {
                if !value.isEmpty {
                    let policiesValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "policies", value: policiesValue)
                }
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case durationInHours
            case acknowledgeAccountSubjects
            case policies
        }
    }

    public struct ModEventReverseTakedown: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventReverseTakedown"
        public let comment: String?

        // Standard initializer
        public init(
            comment: String?
        ) {
            self.comment = comment
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
        }
    }

    public struct ModEventResolveAppeal: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventResolveAppeal"
        public let comment: String?

        // Standard initializer
        public init(
            comment: String?
        ) {
            self.comment = comment
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
        }
    }

    public struct ModEventComment: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventComment"
        public let comment: String?
        public let sticky: Bool?

        // Standard initializer
        public init(
            comment: String?, sticky: Bool?
        ) {
            self.comment = comment
            self.sticky = sticky
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                sticky = try container.decodeIfPresent(Bool.self, forKey: .sticky)

            } catch {
                LogManager.logError("Decoding error for property 'sticky': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            if let value = sticky {
                try container.encode(value, forKey: .sticky)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = sticky {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            if sticky != other.sticky {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            if let value = sticky {
                let stickyValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "sticky", value: stickyValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case sticky
        }
    }

    public struct ModEventReport: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventReport"
        public let comment: String?
        public let isReporterMuted: Bool?
        public let reportType: ComAtprotoModerationDefs.ReasonType

        // Standard initializer
        public init(
            comment: String?, isReporterMuted: Bool?, reportType: ComAtprotoModerationDefs.ReasonType
        ) {
            self.comment = comment
            self.isReporterMuted = isReporterMuted
            self.reportType = reportType
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                isReporterMuted = try container.decodeIfPresent(Bool.self, forKey: .isReporterMuted)

            } catch {
                LogManager.logError("Decoding error for property 'isReporterMuted': \(error)")
                throw error
            }
            do {
                reportType = try container.decode(ComAtprotoModerationDefs.ReasonType.self, forKey: .reportType)

            } catch {
                LogManager.logError("Decoding error for property 'reportType': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            if let value = isReporterMuted {
                try container.encode(value, forKey: .isReporterMuted)
            }

            try container.encode(reportType, forKey: .reportType)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = isReporterMuted {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(reportType)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            if isReporterMuted != other.isReporterMuted {
                return false
            }

            if reportType != other.reportType {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            if let value = isReporterMuted {
                let isReporterMutedValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "isReporterMuted", value: isReporterMutedValue)
            }

            let reportTypeValue = try (reportType as? DAGCBOREncodable)?.toCBORValue() ?? reportType
            map = map.adding(key: "reportType", value: reportTypeValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case isReporterMuted
            case reportType
        }
    }

    public struct ModEventLabel: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventLabel"
        public let comment: String?
        public let createLabelVals: [String]
        public let negateLabelVals: [String]
        public let durationInHours: Int?

        // Standard initializer
        public init(
            comment: String?, createLabelVals: [String], negateLabelVals: [String], durationInHours: Int?
        ) {
            self.comment = comment
            self.createLabelVals = createLabelVals
            self.negateLabelVals = negateLabelVals
            self.durationInHours = durationInHours
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                createLabelVals = try container.decode([String].self, forKey: .createLabelVals)

            } catch {
                LogManager.logError("Decoding error for property 'createLabelVals': \(error)")
                throw error
            }
            do {
                negateLabelVals = try container.decode([String].self, forKey: .negateLabelVals)

            } catch {
                LogManager.logError("Decoding error for property 'negateLabelVals': \(error)")
                throw error
            }
            do {
                durationInHours = try container.decodeIfPresent(Int.self, forKey: .durationInHours)

            } catch {
                LogManager.logError("Decoding error for property 'durationInHours': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            try container.encode(createLabelVals, forKey: .createLabelVals)

            try container.encode(negateLabelVals, forKey: .negateLabelVals)

            if let value = durationInHours {
                try container.encode(value, forKey: .durationInHours)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(createLabelVals)
            hasher.combine(negateLabelVals)
            if let value = durationInHours {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            if createLabelVals != other.createLabelVals {
                return false
            }

            if negateLabelVals != other.negateLabelVals {
                return false
            }

            if durationInHours != other.durationInHours {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            let createLabelValsValue = try (createLabelVals as? DAGCBOREncodable)?.toCBORValue() ?? createLabelVals
            map = map.adding(key: "createLabelVals", value: createLabelValsValue)

            let negateLabelValsValue = try (negateLabelVals as? DAGCBOREncodable)?.toCBORValue() ?? negateLabelVals
            map = map.adding(key: "negateLabelVals", value: negateLabelValsValue)

            if let value = durationInHours {
                let durationInHoursValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "durationInHours", value: durationInHoursValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case createLabelVals
            case negateLabelVals
            case durationInHours
        }
    }

    public struct ModEventPriorityScore: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventPriorityScore"
        public let comment: String?
        public let score: Int

        // Standard initializer
        public init(
            comment: String?, score: Int
        ) {
            self.comment = comment
            self.score = score
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                score = try container.decode(Int.self, forKey: .score)

            } catch {
                LogManager.logError("Decoding error for property 'score': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            try container.encode(score, forKey: .score)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(score)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            if score != other.score {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            let scoreValue = try (score as? DAGCBOREncodable)?.toCBORValue() ?? score
            map = map.adding(key: "score", value: scoreValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case score
        }
    }

    public struct ModEventAcknowledge: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventAcknowledge"
        public let comment: String?
        public let acknowledgeAccountSubjects: Bool?

        // Standard initializer
        public init(
            comment: String?, acknowledgeAccountSubjects: Bool?
        ) {
            self.comment = comment
            self.acknowledgeAccountSubjects = acknowledgeAccountSubjects
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                acknowledgeAccountSubjects = try container.decodeIfPresent(Bool.self, forKey: .acknowledgeAccountSubjects)

            } catch {
                LogManager.logError("Decoding error for property 'acknowledgeAccountSubjects': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            if let value = acknowledgeAccountSubjects {
                try container.encode(value, forKey: .acknowledgeAccountSubjects)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = acknowledgeAccountSubjects {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            if acknowledgeAccountSubjects != other.acknowledgeAccountSubjects {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            if let value = acknowledgeAccountSubjects {
                let acknowledgeAccountSubjectsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "acknowledgeAccountSubjects", value: acknowledgeAccountSubjectsValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case acknowledgeAccountSubjects
        }
    }

    public struct ModEventEscalate: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventEscalate"
        public let comment: String?

        // Standard initializer
        public init(
            comment: String?
        ) {
            self.comment = comment
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
        }
    }

    public struct ModEventMute: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventMute"
        public let comment: String?
        public let durationInHours: Int

        // Standard initializer
        public init(
            comment: String?, durationInHours: Int
        ) {
            self.comment = comment
            self.durationInHours = durationInHours
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                durationInHours = try container.decode(Int.self, forKey: .durationInHours)

            } catch {
                LogManager.logError("Decoding error for property 'durationInHours': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            try container.encode(durationInHours, forKey: .durationInHours)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(durationInHours)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            if durationInHours != other.durationInHours {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            let durationInHoursValue = try (durationInHours as? DAGCBOREncodable)?.toCBORValue() ?? durationInHours
            map = map.adding(key: "durationInHours", value: durationInHoursValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case durationInHours
        }
    }

    public struct ModEventUnmute: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventUnmute"
        public let comment: String?

        // Standard initializer
        public init(
            comment: String?
        ) {
            self.comment = comment
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
        }
    }

    public struct ModEventMuteReporter: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventMuteReporter"
        public let comment: String?
        public let durationInHours: Int?

        // Standard initializer
        public init(
            comment: String?, durationInHours: Int?
        ) {
            self.comment = comment
            self.durationInHours = durationInHours
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                durationInHours = try container.decodeIfPresent(Int.self, forKey: .durationInHours)

            } catch {
                LogManager.logError("Decoding error for property 'durationInHours': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            if let value = durationInHours {
                try container.encode(value, forKey: .durationInHours)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = durationInHours {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            if durationInHours != other.durationInHours {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            if let value = durationInHours {
                let durationInHoursValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "durationInHours", value: durationInHoursValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case durationInHours
        }
    }

    public struct ModEventUnmuteReporter: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventUnmuteReporter"
        public let comment: String?

        // Standard initializer
        public init(
            comment: String?
        ) {
            self.comment = comment
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
        }
    }

    public struct ModEventEmail: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventEmail"
        public let subjectLine: String
        public let content: String?
        public let comment: String?

        // Standard initializer
        public init(
            subjectLine: String, content: String?, comment: String?
        ) {
            self.subjectLine = subjectLine
            self.content = content
            self.comment = comment
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                subjectLine = try container.decode(String.self, forKey: .subjectLine)

            } catch {
                LogManager.logError("Decoding error for property 'subjectLine': \(error)")
                throw error
            }
            do {
                content = try container.decodeIfPresent(String.self, forKey: .content)

            } catch {
                LogManager.logError("Decoding error for property 'content': \(error)")
                throw error
            }
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(subjectLine, forKey: .subjectLine)

            if let value = content {
                try container.encode(value, forKey: .content)
            }

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(subjectLine)
            if let value = content {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if subjectLine != other.subjectLine {
                return false
            }

            if content != other.content {
                return false
            }

            if comment != other.comment {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let subjectLineValue = try (subjectLine as? DAGCBOREncodable)?.toCBORValue() ?? subjectLine
            map = map.adding(key: "subjectLine", value: subjectLineValue)

            if let value = content {
                let contentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "content", value: contentValue)
            }

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case subjectLine
            case content
            case comment
        }
    }

    public struct ModEventDivert: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventDivert"
        public let comment: String?

        // Standard initializer
        public init(
            comment: String?
        ) {
            self.comment = comment
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
        }
    }

    public struct ModEventTag: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventTag"
        public let add: [String]
        public let remove: [String]
        public let comment: String?

        // Standard initializer
        public init(
            add: [String], remove: [String], comment: String?
        ) {
            self.add = add
            self.remove = remove
            self.comment = comment
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                add = try container.decode([String].self, forKey: .add)

            } catch {
                LogManager.logError("Decoding error for property 'add': \(error)")
                throw error
            }
            do {
                remove = try container.decode([String].self, forKey: .remove)

            } catch {
                LogManager.logError("Decoding error for property 'remove': \(error)")
                throw error
            }
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(add, forKey: .add)

            try container.encode(remove, forKey: .remove)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(add)
            hasher.combine(remove)
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if add != other.add {
                return false
            }

            if remove != other.remove {
                return false
            }

            if comment != other.comment {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let addValue = try (add as? DAGCBOREncodable)?.toCBORValue() ?? add
            map = map.adding(key: "add", value: addValue)

            let removeValue = try (remove as? DAGCBOREncodable)?.toCBORValue() ?? remove
            map = map.adding(key: "remove", value: removeValue)

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case add
            case remove
            case comment
        }
    }

    public struct AccountEvent: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#accountEvent"
        public let comment: String?
        public let active: Bool
        public let status: String?
        public let timestamp: ATProtocolDate

        // Standard initializer
        public init(
            comment: String?, active: Bool, status: String?, timestamp: ATProtocolDate
        ) {
            self.comment = comment
            self.active = active
            self.status = status
            self.timestamp = timestamp
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                active = try container.decode(Bool.self, forKey: .active)

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
            do {
                timestamp = try container.decode(ATProtocolDate.self, forKey: .timestamp)

            } catch {
                LogManager.logError("Decoding error for property 'timestamp': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            try container.encode(active, forKey: .active)

            if let value = status {
                try container.encode(value, forKey: .status)
            }

            try container.encode(timestamp, forKey: .timestamp)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(active)
            if let value = status {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(timestamp)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            if active != other.active {
                return false
            }

            if status != other.status {
                return false
            }

            if timestamp != other.timestamp {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            let activeValue = try (active as? DAGCBOREncodable)?.toCBORValue() ?? active
            map = map.adding(key: "active", value: activeValue)

            if let value = status {
                let statusValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "status", value: statusValue)
            }

            let timestampValue = try (timestamp as? DAGCBOREncodable)?.toCBORValue() ?? timestamp
            map = map.adding(key: "timestamp", value: timestampValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case active
            case status
            case timestamp
        }
    }

    public struct IdentityEvent: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#identityEvent"
        public let comment: String?
        public let handle: Handle?
        public let pdsHost: URI?
        public let tombstone: Bool?
        public let timestamp: ATProtocolDate

        // Standard initializer
        public init(
            comment: String?, handle: Handle?, pdsHost: URI?, tombstone: Bool?, timestamp: ATProtocolDate
        ) {
            self.comment = comment
            self.handle = handle
            self.pdsHost = pdsHost
            self.tombstone = tombstone
            self.timestamp = timestamp
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                handle = try container.decodeIfPresent(Handle.self, forKey: .handle)

            } catch {
                LogManager.logError("Decoding error for property 'handle': \(error)")
                throw error
            }
            do {
                pdsHost = try container.decodeIfPresent(URI.self, forKey: .pdsHost)

            } catch {
                LogManager.logError("Decoding error for property 'pdsHost': \(error)")
                throw error
            }
            do {
                tombstone = try container.decodeIfPresent(Bool.self, forKey: .tombstone)

            } catch {
                LogManager.logError("Decoding error for property 'tombstone': \(error)")
                throw error
            }
            do {
                timestamp = try container.decode(ATProtocolDate.self, forKey: .timestamp)

            } catch {
                LogManager.logError("Decoding error for property 'timestamp': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            if let value = handle {
                try container.encode(value, forKey: .handle)
            }

            if let value = pdsHost {
                try container.encode(value, forKey: .pdsHost)
            }

            if let value = tombstone {
                try container.encode(value, forKey: .tombstone)
            }

            try container.encode(timestamp, forKey: .timestamp)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = handle {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = pdsHost {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = tombstone {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(timestamp)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            if handle != other.handle {
                return false
            }

            if pdsHost != other.pdsHost {
                return false
            }

            if tombstone != other.tombstone {
                return false
            }

            if timestamp != other.timestamp {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            if let value = handle {
                let handleValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "handle", value: handleValue)
            }

            if let value = pdsHost {
                let pdsHostValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "pdsHost", value: pdsHostValue)
            }

            if let value = tombstone {
                let tombstoneValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "tombstone", value: tombstoneValue)
            }

            let timestampValue = try (timestamp as? DAGCBOREncodable)?.toCBORValue() ?? timestamp
            map = map.adding(key: "timestamp", value: timestampValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case handle
            case pdsHost
            case tombstone
            case timestamp
        }
    }

    public struct RecordEvent: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#recordEvent"
        public let comment: String?
        public let op: String
        public let cid: CID?
        public let timestamp: ATProtocolDate

        // Standard initializer
        public init(
            comment: String?, op: String, cid: CID?, timestamp: ATProtocolDate
        ) {
            self.comment = comment
            self.op = op
            self.cid = cid
            self.timestamp = timestamp
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decodeIfPresent(String.self, forKey: .comment)

            } catch {
                LogManager.logError("Decoding error for property 'comment': \(error)")
                throw error
            }
            do {
                op = try container.decode(String.self, forKey: .op)

            } catch {
                LogManager.logError("Decoding error for property 'op': \(error)")
                throw error
            }
            do {
                cid = try container.decodeIfPresent(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                timestamp = try container.decode(ATProtocolDate.self, forKey: .timestamp)

            } catch {
                LogManager.logError("Decoding error for property 'timestamp': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            try container.encode(op, forKey: .op)

            if let value = cid {
                try container.encode(value, forKey: .cid)
            }

            try container.encode(timestamp, forKey: .timestamp)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(op)
            if let value = cid {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(timestamp)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if comment != other.comment {
                return false
            }

            if op != other.op {
                return false
            }

            if cid != other.cid {
                return false
            }

            if timestamp != other.timestamp {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = comment {
                let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "comment", value: commentValue)
            }

            let opValue = try (op as? DAGCBOREncodable)?.toCBORValue() ?? op
            map = map.adding(key: "op", value: opValue)

            if let value = cid {
                let cidValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cid", value: cidValue)
            }

            let timestampValue = try (timestamp as? DAGCBOREncodable)?.toCBORValue() ?? timestamp
            map = map.adding(key: "timestamp", value: timestampValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case op
            case cid
            case timestamp
        }
    }

    public struct RepoView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#repoView"
        public let did: DID
        public let handle: Handle
        public let email: String?
        public let relatedRecords: [ATProtocolValueContainer]
        public let indexedAt: ATProtocolDate
        public let moderation: Moderation
        public let invitedBy: ComAtprotoServerDefs.InviteCode?
        public let invitesDisabled: Bool?
        public let inviteNote: String?
        public let deactivatedAt: ATProtocolDate?
        public let threatSignatures: [ComAtprotoAdminDefs.ThreatSignature]?

        // Standard initializer
        public init(
            did: DID, handle: Handle, email: String?, relatedRecords: [ATProtocolValueContainer], indexedAt: ATProtocolDate, moderation: Moderation, invitedBy: ComAtprotoServerDefs.InviteCode?, invitesDisabled: Bool?, inviteNote: String?, deactivatedAt: ATProtocolDate?, threatSignatures: [ComAtprotoAdminDefs.ThreatSignature]?
        ) {
            self.did = did
            self.handle = handle
            self.email = email
            self.relatedRecords = relatedRecords
            self.indexedAt = indexedAt
            self.moderation = moderation
            self.invitedBy = invitedBy
            self.invitesDisabled = invitesDisabled
            self.inviteNote = inviteNote
            self.deactivatedAt = deactivatedAt
            self.threatSignatures = threatSignatures
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                handle = try container.decode(Handle.self, forKey: .handle)

            } catch {
                LogManager.logError("Decoding error for property 'handle': \(error)")
                throw error
            }
            do {
                email = try container.decodeIfPresent(String.self, forKey: .email)

            } catch {
                LogManager.logError("Decoding error for property 'email': \(error)")
                throw error
            }
            do {
                relatedRecords = try container.decode([ATProtocolValueContainer].self, forKey: .relatedRecords)

            } catch {
                LogManager.logError("Decoding error for property 'relatedRecords': \(error)")
                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                moderation = try container.decode(Moderation.self, forKey: .moderation)

            } catch {
                LogManager.logError("Decoding error for property 'moderation': \(error)")
                throw error
            }
            do {
                invitedBy = try container.decodeIfPresent(ComAtprotoServerDefs.InviteCode.self, forKey: .invitedBy)

            } catch {
                LogManager.logError("Decoding error for property 'invitedBy': \(error)")
                throw error
            }
            do {
                invitesDisabled = try container.decodeIfPresent(Bool.self, forKey: .invitesDisabled)

            } catch {
                LogManager.logError("Decoding error for property 'invitesDisabled': \(error)")
                throw error
            }
            do {
                inviteNote = try container.decodeIfPresent(String.self, forKey: .inviteNote)

            } catch {
                LogManager.logError("Decoding error for property 'inviteNote': \(error)")
                throw error
            }
            do {
                deactivatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .deactivatedAt)

            } catch {
                LogManager.logError("Decoding error for property 'deactivatedAt': \(error)")
                throw error
            }
            do {
                threatSignatures = try container.decodeIfPresent([ComAtprotoAdminDefs.ThreatSignature].self, forKey: .threatSignatures)

            } catch {
                LogManager.logError("Decoding error for property 'threatSignatures': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)

            try container.encode(handle, forKey: .handle)

            if let value = email {
                try container.encode(value, forKey: .email)
            }

            try container.encode(relatedRecords, forKey: .relatedRecords)

            try container.encode(indexedAt, forKey: .indexedAt)

            try container.encode(moderation, forKey: .moderation)

            if let value = invitedBy {
                try container.encode(value, forKey: .invitedBy)
            }

            if let value = invitesDisabled {
                try container.encode(value, forKey: .invitesDisabled)
            }

            if let value = inviteNote {
                try container.encode(value, forKey: .inviteNote)
            }

            if let value = deactivatedAt {
                try container.encode(value, forKey: .deactivatedAt)
            }

            if let value = threatSignatures {
                if !value.isEmpty {
                    try container.encode(value, forKey: .threatSignatures)
                }
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(handle)
            if let value = email {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(relatedRecords)
            hasher.combine(indexedAt)
            hasher.combine(moderation)
            if let value = invitedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = invitesDisabled {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = inviteNote {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deactivatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = threatSignatures {
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

            if handle != other.handle {
                return false
            }

            if email != other.email {
                return false
            }

            if relatedRecords != other.relatedRecords {
                return false
            }

            if indexedAt != other.indexedAt {
                return false
            }

            if moderation != other.moderation {
                return false
            }

            if invitedBy != other.invitedBy {
                return false
            }

            if invitesDisabled != other.invitesDisabled {
                return false
            }

            if inviteNote != other.inviteNote {
                return false
            }

            if deactivatedAt != other.deactivatedAt {
                return false
            }

            if threatSignatures != other.threatSignatures {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            let handleValue = try (handle as? DAGCBOREncodable)?.toCBORValue() ?? handle
            map = map.adding(key: "handle", value: handleValue)

            if let value = email {
                let emailValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "email", value: emailValue)
            }

            let relatedRecordsValue = try (relatedRecords as? DAGCBOREncodable)?.toCBORValue() ?? relatedRecords
            map = map.adding(key: "relatedRecords", value: relatedRecordsValue)

            let indexedAtValue = try (indexedAt as? DAGCBOREncodable)?.toCBORValue() ?? indexedAt
            map = map.adding(key: "indexedAt", value: indexedAtValue)

            let moderationValue = try (moderation as? DAGCBOREncodable)?.toCBORValue() ?? moderation
            map = map.adding(key: "moderation", value: moderationValue)

            if let value = invitedBy {
                let invitedByValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "invitedBy", value: invitedByValue)
            }

            if let value = invitesDisabled {
                let invitesDisabledValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "invitesDisabled", value: invitesDisabledValue)
            }

            if let value = inviteNote {
                let inviteNoteValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "inviteNote", value: inviteNoteValue)
            }

            if let value = deactivatedAt {
                let deactivatedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "deactivatedAt", value: deactivatedAtValue)
            }

            if let value = threatSignatures {
                if !value.isEmpty {
                    let threatSignaturesValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "threatSignatures", value: threatSignaturesValue)
                }
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case handle
            case email
            case relatedRecords
            case indexedAt
            case moderation
            case invitedBy
            case invitesDisabled
            case inviteNote
            case deactivatedAt
            case threatSignatures
        }
    }

    public struct RepoViewDetail: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#repoViewDetail"
        public let did: DID
        public let handle: Handle
        public let email: String?
        public let relatedRecords: [ATProtocolValueContainer]
        public let indexedAt: ATProtocolDate
        public let moderation: ModerationDetail
        public let labels: [ComAtprotoLabelDefs.Label]?
        public let invitedBy: ComAtprotoServerDefs.InviteCode?
        public let invites: [ComAtprotoServerDefs.InviteCode]?
        public let invitesDisabled: Bool?
        public let inviteNote: String?
        public let emailConfirmedAt: ATProtocolDate?
        public let deactivatedAt: ATProtocolDate?
        public let threatSignatures: [ComAtprotoAdminDefs.ThreatSignature]?

        // Standard initializer
        public init(
            did: DID, handle: Handle, email: String?, relatedRecords: [ATProtocolValueContainer], indexedAt: ATProtocolDate, moderation: ModerationDetail, labels: [ComAtprotoLabelDefs.Label]?, invitedBy: ComAtprotoServerDefs.InviteCode?, invites: [ComAtprotoServerDefs.InviteCode]?, invitesDisabled: Bool?, inviteNote: String?, emailConfirmedAt: ATProtocolDate?, deactivatedAt: ATProtocolDate?, threatSignatures: [ComAtprotoAdminDefs.ThreatSignature]?
        ) {
            self.did = did
            self.handle = handle
            self.email = email
            self.relatedRecords = relatedRecords
            self.indexedAt = indexedAt
            self.moderation = moderation
            self.labels = labels
            self.invitedBy = invitedBy
            self.invites = invites
            self.invitesDisabled = invitesDisabled
            self.inviteNote = inviteNote
            self.emailConfirmedAt = emailConfirmedAt
            self.deactivatedAt = deactivatedAt
            self.threatSignatures = threatSignatures
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                handle = try container.decode(Handle.self, forKey: .handle)

            } catch {
                LogManager.logError("Decoding error for property 'handle': \(error)")
                throw error
            }
            do {
                email = try container.decodeIfPresent(String.self, forKey: .email)

            } catch {
                LogManager.logError("Decoding error for property 'email': \(error)")
                throw error
            }
            do {
                relatedRecords = try container.decode([ATProtocolValueContainer].self, forKey: .relatedRecords)

            } catch {
                LogManager.logError("Decoding error for property 'relatedRecords': \(error)")
                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                moderation = try container.decode(ModerationDetail.self, forKey: .moderation)

            } catch {
                LogManager.logError("Decoding error for property 'moderation': \(error)")
                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
            do {
                invitedBy = try container.decodeIfPresent(ComAtprotoServerDefs.InviteCode.self, forKey: .invitedBy)

            } catch {
                LogManager.logError("Decoding error for property 'invitedBy': \(error)")
                throw error
            }
            do {
                invites = try container.decodeIfPresent([ComAtprotoServerDefs.InviteCode].self, forKey: .invites)

            } catch {
                LogManager.logError("Decoding error for property 'invites': \(error)")
                throw error
            }
            do {
                invitesDisabled = try container.decodeIfPresent(Bool.self, forKey: .invitesDisabled)

            } catch {
                LogManager.logError("Decoding error for property 'invitesDisabled': \(error)")
                throw error
            }
            do {
                inviteNote = try container.decodeIfPresent(String.self, forKey: .inviteNote)

            } catch {
                LogManager.logError("Decoding error for property 'inviteNote': \(error)")
                throw error
            }
            do {
                emailConfirmedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .emailConfirmedAt)

            } catch {
                LogManager.logError("Decoding error for property 'emailConfirmedAt': \(error)")
                throw error
            }
            do {
                deactivatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .deactivatedAt)

            } catch {
                LogManager.logError("Decoding error for property 'deactivatedAt': \(error)")
                throw error
            }
            do {
                threatSignatures = try container.decodeIfPresent([ComAtprotoAdminDefs.ThreatSignature].self, forKey: .threatSignatures)

            } catch {
                LogManager.logError("Decoding error for property 'threatSignatures': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)

            try container.encode(handle, forKey: .handle)

            if let value = email {
                try container.encode(value, forKey: .email)
            }

            try container.encode(relatedRecords, forKey: .relatedRecords)

            try container.encode(indexedAt, forKey: .indexedAt)

            try container.encode(moderation, forKey: .moderation)

            if let value = labels {
                if !value.isEmpty {
                    try container.encode(value, forKey: .labels)
                }
            }

            if let value = invitedBy {
                try container.encode(value, forKey: .invitedBy)
            }

            if let value = invites {
                if !value.isEmpty {
                    try container.encode(value, forKey: .invites)
                }
            }

            if let value = invitesDisabled {
                try container.encode(value, forKey: .invitesDisabled)
            }

            if let value = inviteNote {
                try container.encode(value, forKey: .inviteNote)
            }

            if let value = emailConfirmedAt {
                try container.encode(value, forKey: .emailConfirmedAt)
            }

            if let value = deactivatedAt {
                try container.encode(value, forKey: .deactivatedAt)
            }

            if let value = threatSignatures {
                if !value.isEmpty {
                    try container.encode(value, forKey: .threatSignatures)
                }
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(handle)
            if let value = email {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(relatedRecords)
            hasher.combine(indexedAt)
            hasher.combine(moderation)
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = invitedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = invites {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = invitesDisabled {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = inviteNote {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = emailConfirmedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deactivatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = threatSignatures {
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

            if handle != other.handle {
                return false
            }

            if email != other.email {
                return false
            }

            if relatedRecords != other.relatedRecords {
                return false
            }

            if indexedAt != other.indexedAt {
                return false
            }

            if moderation != other.moderation {
                return false
            }

            if labels != other.labels {
                return false
            }

            if invitedBy != other.invitedBy {
                return false
            }

            if invites != other.invites {
                return false
            }

            if invitesDisabled != other.invitesDisabled {
                return false
            }

            if inviteNote != other.inviteNote {
                return false
            }

            if emailConfirmedAt != other.emailConfirmedAt {
                return false
            }

            if deactivatedAt != other.deactivatedAt {
                return false
            }

            if threatSignatures != other.threatSignatures {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            let handleValue = try (handle as? DAGCBOREncodable)?.toCBORValue() ?? handle
            map = map.adding(key: "handle", value: handleValue)

            if let value = email {
                let emailValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "email", value: emailValue)
            }

            let relatedRecordsValue = try (relatedRecords as? DAGCBOREncodable)?.toCBORValue() ?? relatedRecords
            map = map.adding(key: "relatedRecords", value: relatedRecordsValue)

            let indexedAtValue = try (indexedAt as? DAGCBOREncodable)?.toCBORValue() ?? indexedAt
            map = map.adding(key: "indexedAt", value: indexedAtValue)

            let moderationValue = try (moderation as? DAGCBOREncodable)?.toCBORValue() ?? moderation
            map = map.adding(key: "moderation", value: moderationValue)

            if let value = labels {
                if !value.isEmpty {
                    let labelsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "labels", value: labelsValue)
                }
            }

            if let value = invitedBy {
                let invitedByValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "invitedBy", value: invitedByValue)
            }

            if let value = invites {
                if !value.isEmpty {
                    let invitesValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "invites", value: invitesValue)
                }
            }

            if let value = invitesDisabled {
                let invitesDisabledValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "invitesDisabled", value: invitesDisabledValue)
            }

            if let value = inviteNote {
                let inviteNoteValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "inviteNote", value: inviteNoteValue)
            }

            if let value = emailConfirmedAt {
                let emailConfirmedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "emailConfirmedAt", value: emailConfirmedAtValue)
            }

            if let value = deactivatedAt {
                let deactivatedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "deactivatedAt", value: deactivatedAtValue)
            }

            if let value = threatSignatures {
                if !value.isEmpty {
                    let threatSignaturesValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "threatSignatures", value: threatSignaturesValue)
                }
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case handle
            case email
            case relatedRecords
            case indexedAt
            case moderation
            case labels
            case invitedBy
            case invites
            case invitesDisabled
            case inviteNote
            case emailConfirmedAt
            case deactivatedAt
            case threatSignatures
        }
    }

    public struct RepoViewNotFound: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#repoViewNotFound"
        public let did: DID

        // Standard initializer
        public init(
            did: DID
        ) {
            self.did = did
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if did != other.did {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }

    public struct RecordView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#recordView"
        public let uri: ATProtocolURI
        public let cid: CID
        public let value: ATProtocolValueContainer
        public let blobCids: [CID]
        public let indexedAt: ATProtocolDate
        public let moderation: Moderation
        public let repo: RepoView

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, value: ATProtocolValueContainer, blobCids: [CID], indexedAt: ATProtocolDate, moderation: Moderation, repo: RepoView
        ) {
            self.uri = uri
            self.cid = cid
            self.value = value
            self.blobCids = blobCids
            self.indexedAt = indexedAt
            self.moderation = moderation
            self.repo = repo
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
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                value = try container.decode(ATProtocolValueContainer.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            do {
                blobCids = try container.decode([CID].self, forKey: .blobCids)

            } catch {
                LogManager.logError("Decoding error for property 'blobCids': \(error)")
                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                moderation = try container.decode(Moderation.self, forKey: .moderation)

            } catch {
                LogManager.logError("Decoding error for property 'moderation': \(error)")
                throw error
            }
            do {
                repo = try container.decode(RepoView.self, forKey: .repo)

            } catch {
                LogManager.logError("Decoding error for property 'repo': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            try container.encode(value, forKey: .value)

            try container.encode(blobCids, forKey: .blobCids)

            try container.encode(indexedAt, forKey: .indexedAt)

            try container.encode(moderation, forKey: .moderation)

            try container.encode(repo, forKey: .repo)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(value)
            hasher.combine(blobCids)
            hasher.combine(indexedAt)
            hasher.combine(moderation)
            hasher.combine(repo)
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

            if blobCids != other.blobCids {
                return false
            }

            if indexedAt != other.indexedAt {
                return false
            }

            if moderation != other.moderation {
                return false
            }

            if repo != other.repo {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let uriValue = try (uri as? DAGCBOREncodable)?.toCBORValue() ?? uri
            map = map.adding(key: "uri", value: uriValue)

            let cidValue = try (cid as? DAGCBOREncodable)?.toCBORValue() ?? cid
            map = map.adding(key: "cid", value: cidValue)

            let valueValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
            map = map.adding(key: "value", value: valueValue)

            let blobCidsValue = try (blobCids as? DAGCBOREncodable)?.toCBORValue() ?? blobCids
            map = map.adding(key: "blobCids", value: blobCidsValue)

            let indexedAtValue = try (indexedAt as? DAGCBOREncodable)?.toCBORValue() ?? indexedAt
            map = map.adding(key: "indexedAt", value: indexedAtValue)

            let moderationValue = try (moderation as? DAGCBOREncodable)?.toCBORValue() ?? moderation
            map = map.adding(key: "moderation", value: moderationValue)

            let repoValue = try (repo as? DAGCBOREncodable)?.toCBORValue() ?? repo
            map = map.adding(key: "repo", value: repoValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case value
            case blobCids
            case indexedAt
            case moderation
            case repo
        }
    }

    public struct RecordViewDetail: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#recordViewDetail"
        public let uri: ATProtocolURI
        public let cid: CID
        public let value: ATProtocolValueContainer
        public let blobs: [BlobView]
        public let labels: [ComAtprotoLabelDefs.Label]?
        public let indexedAt: ATProtocolDate
        public let moderation: ModerationDetail
        public let repo: RepoView

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, value: ATProtocolValueContainer, blobs: [BlobView], labels: [ComAtprotoLabelDefs.Label]?, indexedAt: ATProtocolDate, moderation: ModerationDetail, repo: RepoView
        ) {
            self.uri = uri
            self.cid = cid
            self.value = value
            self.blobs = blobs
            self.labels = labels
            self.indexedAt = indexedAt
            self.moderation = moderation
            self.repo = repo
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
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                value = try container.decode(ATProtocolValueContainer.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            do {
                blobs = try container.decode([BlobView].self, forKey: .blobs)

            } catch {
                LogManager.logError("Decoding error for property 'blobs': \(error)")
                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                moderation = try container.decode(ModerationDetail.self, forKey: .moderation)

            } catch {
                LogManager.logError("Decoding error for property 'moderation': \(error)")
                throw error
            }
            do {
                repo = try container.decode(RepoView.self, forKey: .repo)

            } catch {
                LogManager.logError("Decoding error for property 'repo': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            try container.encode(value, forKey: .value)

            try container.encode(blobs, forKey: .blobs)

            if let value = labels {
                if !value.isEmpty {
                    try container.encode(value, forKey: .labels)
                }
            }

            try container.encode(indexedAt, forKey: .indexedAt)

            try container.encode(moderation, forKey: .moderation)

            try container.encode(repo, forKey: .repo)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(value)
            hasher.combine(blobs)
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(indexedAt)
            hasher.combine(moderation)
            hasher.combine(repo)
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

            if blobs != other.blobs {
                return false
            }

            if labels != other.labels {
                return false
            }

            if indexedAt != other.indexedAt {
                return false
            }

            if moderation != other.moderation {
                return false
            }

            if repo != other.repo {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let uriValue = try (uri as? DAGCBOREncodable)?.toCBORValue() ?? uri
            map = map.adding(key: "uri", value: uriValue)

            let cidValue = try (cid as? DAGCBOREncodable)?.toCBORValue() ?? cid
            map = map.adding(key: "cid", value: cidValue)

            let valueValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
            map = map.adding(key: "value", value: valueValue)

            let blobsValue = try (blobs as? DAGCBOREncodable)?.toCBORValue() ?? blobs
            map = map.adding(key: "blobs", value: blobsValue)

            if let value = labels {
                if !value.isEmpty {
                    let labelsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "labels", value: labelsValue)
                }
            }

            let indexedAtValue = try (indexedAt as? DAGCBOREncodable)?.toCBORValue() ?? indexedAt
            map = map.adding(key: "indexedAt", value: indexedAtValue)

            let moderationValue = try (moderation as? DAGCBOREncodable)?.toCBORValue() ?? moderation
            map = map.adding(key: "moderation", value: moderationValue)

            let repoValue = try (repo as? DAGCBOREncodable)?.toCBORValue() ?? repo
            map = map.adding(key: "repo", value: repoValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case value
            case blobs
            case labels
            case indexedAt
            case moderation
            case repo
        }
    }

    public struct RecordViewNotFound: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#recordViewNotFound"
        public let uri: ATProtocolURI

        // Standard initializer
        public init(
            uri: ATProtocolURI
        ) {
            self.uri = uri
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
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if uri != other.uri {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let uriValue = try (uri as? DAGCBOREncodable)?.toCBORValue() ?? uri
            map = map.adding(key: "uri", value: uriValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
        }
    }

    public struct Moderation: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#moderation"
        public let subjectStatus: SubjectStatusView?

        // Standard initializer
        public init(
            subjectStatus: SubjectStatusView?
        ) {
            self.subjectStatus = subjectStatus
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                subjectStatus = try container.decodeIfPresent(SubjectStatusView.self, forKey: .subjectStatus)

            } catch {
                LogManager.logError("Decoding error for property 'subjectStatus': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = subjectStatus {
                try container.encode(value, forKey: .subjectStatus)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = subjectStatus {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if subjectStatus != other.subjectStatus {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = subjectStatus {
                let subjectStatusValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "subjectStatus", value: subjectStatusValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case subjectStatus
        }
    }

    public struct ModerationDetail: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#moderationDetail"
        public let subjectStatus: SubjectStatusView?

        // Standard initializer
        public init(
            subjectStatus: SubjectStatusView?
        ) {
            self.subjectStatus = subjectStatus
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                subjectStatus = try container.decodeIfPresent(SubjectStatusView.self, forKey: .subjectStatus)

            } catch {
                LogManager.logError("Decoding error for property 'subjectStatus': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = subjectStatus {
                try container.encode(value, forKey: .subjectStatus)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = subjectStatus {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if subjectStatus != other.subjectStatus {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            if let value = subjectStatus {
                let subjectStatusValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "subjectStatus", value: subjectStatusValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case subjectStatus
        }
    }

    public struct BlobView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#blobView"
        public let cid: CID
        public let mimeType: String
        public let size: Int
        public let createdAt: ATProtocolDate
        public let details: BlobViewDetailsUnion?
        public let moderation: Moderation?

        // Standard initializer
        public init(
            cid: CID, mimeType: String, size: Int, createdAt: ATProtocolDate, details: BlobViewDetailsUnion?, moderation: Moderation?
        ) {
            self.cid = cid
            self.mimeType = mimeType
            self.size = size
            self.createdAt = createdAt
            self.details = details
            self.moderation = moderation
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                mimeType = try container.decode(String.self, forKey: .mimeType)

            } catch {
                LogManager.logError("Decoding error for property 'mimeType': \(error)")
                throw error
            }
            do {
                size = try container.decode(Int.self, forKey: .size)

            } catch {
                LogManager.logError("Decoding error for property 'size': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                details = try container.decodeIfPresent(BlobViewDetailsUnion.self, forKey: .details)

            } catch {
                LogManager.logError("Decoding error for property 'details': \(error)")
                throw error
            }
            do {
                moderation = try container.decodeIfPresent(Moderation.self, forKey: .moderation)

            } catch {
                LogManager.logError("Decoding error for property 'moderation': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(cid, forKey: .cid)

            try container.encode(mimeType, forKey: .mimeType)

            try container.encode(size, forKey: .size)

            try container.encode(createdAt, forKey: .createdAt)

            if let value = details {
                try container.encode(value, forKey: .details)
            }

            if let value = moderation {
                try container.encode(value, forKey: .moderation)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cid)
            hasher.combine(mimeType)
            hasher.combine(size)
            hasher.combine(createdAt)
            if let value = details {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = moderation {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if cid != other.cid {
                return false
            }

            if mimeType != other.mimeType {
                return false
            }

            if size != other.size {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if details != other.details {
                return false
            }

            if moderation != other.moderation {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let cidValue = try (cid as? DAGCBOREncodable)?.toCBORValue() ?? cid
            map = map.adding(key: "cid", value: cidValue)

            let mimeTypeValue = try (mimeType as? DAGCBOREncodable)?.toCBORValue() ?? mimeType
            map = map.adding(key: "mimeType", value: mimeTypeValue)

            let sizeValue = try (size as? DAGCBOREncodable)?.toCBORValue() ?? size
            map = map.adding(key: "size", value: sizeValue)

            let createdAtValue = try (createdAt as? DAGCBOREncodable)?.toCBORValue() ?? createdAt
            map = map.adding(key: "createdAt", value: createdAtValue)

            if let value = details {
                let detailsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "details", value: detailsValue)
            }

            if let value = moderation {
                let moderationValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "moderation", value: moderationValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cid
            case mimeType
            case size
            case createdAt
            case details
            case moderation
        }
    }

    public struct ImageDetails: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#imageDetails"
        public let width: Int
        public let height: Int

        // Standard initializer
        public init(
            width: Int, height: Int
        ) {
            self.width = width
            self.height = height
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                width = try container.decode(Int.self, forKey: .width)

            } catch {
                LogManager.logError("Decoding error for property 'width': \(error)")
                throw error
            }
            do {
                height = try container.decode(Int.self, forKey: .height)

            } catch {
                LogManager.logError("Decoding error for property 'height': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(width, forKey: .width)

            try container.encode(height, forKey: .height)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(width)
            hasher.combine(height)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if width != other.width {
                return false
            }

            if height != other.height {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let widthValue = try (width as? DAGCBOREncodable)?.toCBORValue() ?? width
            map = map.adding(key: "width", value: widthValue)

            let heightValue = try (height as? DAGCBOREncodable)?.toCBORValue() ?? height
            map = map.adding(key: "height", value: heightValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case width
            case height
        }
    }

    public struct VideoDetails: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#videoDetails"
        public let width: Int
        public let height: Int
        public let length: Int

        // Standard initializer
        public init(
            width: Int, height: Int, length: Int
        ) {
            self.width = width
            self.height = height
            self.length = length
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                width = try container.decode(Int.self, forKey: .width)

            } catch {
                LogManager.logError("Decoding error for property 'width': \(error)")
                throw error
            }
            do {
                height = try container.decode(Int.self, forKey: .height)

            } catch {
                LogManager.logError("Decoding error for property 'height': \(error)")
                throw error
            }
            do {
                length = try container.decode(Int.self, forKey: .length)

            } catch {
                LogManager.logError("Decoding error for property 'length': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(width, forKey: .width)

            try container.encode(height, forKey: .height)

            try container.encode(length, forKey: .length)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(width)
            hasher.combine(height)
            hasher.combine(length)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if width != other.width {
                return false
            }

            if height != other.height {
                return false
            }

            if length != other.length {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let widthValue = try (width as? DAGCBOREncodable)?.toCBORValue() ?? width
            map = map.adding(key: "width", value: widthValue)

            let heightValue = try (height as? DAGCBOREncodable)?.toCBORValue() ?? height
            map = map.adding(key: "height", value: heightValue)

            let lengthValue = try (length as? DAGCBOREncodable)?.toCBORValue() ?? length
            map = map.adding(key: "length", value: lengthValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case width
            case height
            case length
        }
    }

    public struct AccountHosting: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#accountHosting"
        public let status: String
        public let updatedAt: ATProtocolDate?
        public let createdAt: ATProtocolDate?
        public let deletedAt: ATProtocolDate?
        public let deactivatedAt: ATProtocolDate?
        public let reactivatedAt: ATProtocolDate?

        // Standard initializer
        public init(
            status: String, updatedAt: ATProtocolDate?, createdAt: ATProtocolDate?, deletedAt: ATProtocolDate?, deactivatedAt: ATProtocolDate?, reactivatedAt: ATProtocolDate?
        ) {
            self.status = status
            self.updatedAt = updatedAt
            self.createdAt = createdAt
            self.deletedAt = deletedAt
            self.deactivatedAt = deactivatedAt
            self.reactivatedAt = reactivatedAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                status = try container.decode(String.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
                throw error
            }
            do {
                updatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .updatedAt)

            } catch {
                LogManager.logError("Decoding error for property 'updatedAt': \(error)")
                throw error
            }
            do {
                createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                deletedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .deletedAt)

            } catch {
                LogManager.logError("Decoding error for property 'deletedAt': \(error)")
                throw error
            }
            do {
                deactivatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .deactivatedAt)

            } catch {
                LogManager.logError("Decoding error for property 'deactivatedAt': \(error)")
                throw error
            }
            do {
                reactivatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .reactivatedAt)

            } catch {
                LogManager.logError("Decoding error for property 'reactivatedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(status, forKey: .status)

            if let value = updatedAt {
                try container.encode(value, forKey: .updatedAt)
            }

            if let value = createdAt {
                try container.encode(value, forKey: .createdAt)
            }

            if let value = deletedAt {
                try container.encode(value, forKey: .deletedAt)
            }

            if let value = deactivatedAt {
                try container.encode(value, forKey: .deactivatedAt)
            }

            if let value = reactivatedAt {
                try container.encode(value, forKey: .reactivatedAt)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(status)
            if let value = updatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = createdAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deletedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deactivatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = reactivatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if status != other.status {
                return false
            }

            if updatedAt != other.updatedAt {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if deletedAt != other.deletedAt {
                return false
            }

            if deactivatedAt != other.deactivatedAt {
                return false
            }

            if reactivatedAt != other.reactivatedAt {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let statusValue = try (status as? DAGCBOREncodable)?.toCBORValue() ?? status
            map = map.adding(key: "status", value: statusValue)

            if let value = updatedAt {
                let updatedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "updatedAt", value: updatedAtValue)
            }

            if let value = createdAt {
                let createdAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "createdAt", value: createdAtValue)
            }

            if let value = deletedAt {
                let deletedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "deletedAt", value: deletedAtValue)
            }

            if let value = deactivatedAt {
                let deactivatedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "deactivatedAt", value: deactivatedAtValue)
            }

            if let value = reactivatedAt {
                let reactivatedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "reactivatedAt", value: reactivatedAtValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case status
            case updatedAt
            case createdAt
            case deletedAt
            case deactivatedAt
            case reactivatedAt
        }
    }

    public struct RecordHosting: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#recordHosting"
        public let status: String
        public let updatedAt: ATProtocolDate?
        public let createdAt: ATProtocolDate?
        public let deletedAt: ATProtocolDate?

        // Standard initializer
        public init(
            status: String, updatedAt: ATProtocolDate?, createdAt: ATProtocolDate?, deletedAt: ATProtocolDate?
        ) {
            self.status = status
            self.updatedAt = updatedAt
            self.createdAt = createdAt
            self.deletedAt = deletedAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                status = try container.decode(String.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
                throw error
            }
            do {
                updatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .updatedAt)

            } catch {
                LogManager.logError("Decoding error for property 'updatedAt': \(error)")
                throw error
            }
            do {
                createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                deletedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .deletedAt)

            } catch {
                LogManager.logError("Decoding error for property 'deletedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(status, forKey: .status)

            if let value = updatedAt {
                try container.encode(value, forKey: .updatedAt)
            }

            if let value = createdAt {
                try container.encode(value, forKey: .createdAt)
            }

            if let value = deletedAt {
                try container.encode(value, forKey: .deletedAt)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(status)
            if let value = updatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = createdAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deletedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if status != other.status {
                return false
            }

            if updatedAt != other.updatedAt {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if deletedAt != other.deletedAt {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let statusValue = try (status as? DAGCBOREncodable)?.toCBORValue() ?? status
            map = map.adding(key: "status", value: statusValue)

            if let value = updatedAt {
                let updatedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "updatedAt", value: updatedAtValue)
            }

            if let value = createdAt {
                let createdAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "createdAt", value: createdAtValue)
            }

            if let value = deletedAt {
                let deletedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "deletedAt", value: deletedAtValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case status
            case updatedAt
            case createdAt
            case deletedAt
        }
    }

    public struct ReporterStats: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#reporterStats"
        public let did: DID
        public let accountReportCount: Int
        public let recordReportCount: Int
        public let reportedAccountCount: Int
        public let reportedRecordCount: Int
        public let takendownAccountCount: Int
        public let takendownRecordCount: Int
        public let labeledAccountCount: Int
        public let labeledRecordCount: Int

        // Standard initializer
        public init(
            did: DID, accountReportCount: Int, recordReportCount: Int, reportedAccountCount: Int, reportedRecordCount: Int, takendownAccountCount: Int, takendownRecordCount: Int, labeledAccountCount: Int, labeledRecordCount: Int
        ) {
            self.did = did
            self.accountReportCount = accountReportCount
            self.recordReportCount = recordReportCount
            self.reportedAccountCount = reportedAccountCount
            self.reportedRecordCount = reportedRecordCount
            self.takendownAccountCount = takendownAccountCount
            self.takendownRecordCount = takendownRecordCount
            self.labeledAccountCount = labeledAccountCount
            self.labeledRecordCount = labeledRecordCount
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                accountReportCount = try container.decode(Int.self, forKey: .accountReportCount)

            } catch {
                LogManager.logError("Decoding error for property 'accountReportCount': \(error)")
                throw error
            }
            do {
                recordReportCount = try container.decode(Int.self, forKey: .recordReportCount)

            } catch {
                LogManager.logError("Decoding error for property 'recordReportCount': \(error)")
                throw error
            }
            do {
                reportedAccountCount = try container.decode(Int.self, forKey: .reportedAccountCount)

            } catch {
                LogManager.logError("Decoding error for property 'reportedAccountCount': \(error)")
                throw error
            }
            do {
                reportedRecordCount = try container.decode(Int.self, forKey: .reportedRecordCount)

            } catch {
                LogManager.logError("Decoding error for property 'reportedRecordCount': \(error)")
                throw error
            }
            do {
                takendownAccountCount = try container.decode(Int.self, forKey: .takendownAccountCount)

            } catch {
                LogManager.logError("Decoding error for property 'takendownAccountCount': \(error)")
                throw error
            }
            do {
                takendownRecordCount = try container.decode(Int.self, forKey: .takendownRecordCount)

            } catch {
                LogManager.logError("Decoding error for property 'takendownRecordCount': \(error)")
                throw error
            }
            do {
                labeledAccountCount = try container.decode(Int.self, forKey: .labeledAccountCount)

            } catch {
                LogManager.logError("Decoding error for property 'labeledAccountCount': \(error)")
                throw error
            }
            do {
                labeledRecordCount = try container.decode(Int.self, forKey: .labeledRecordCount)

            } catch {
                LogManager.logError("Decoding error for property 'labeledRecordCount': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)

            try container.encode(accountReportCount, forKey: .accountReportCount)

            try container.encode(recordReportCount, forKey: .recordReportCount)

            try container.encode(reportedAccountCount, forKey: .reportedAccountCount)

            try container.encode(reportedRecordCount, forKey: .reportedRecordCount)

            try container.encode(takendownAccountCount, forKey: .takendownAccountCount)

            try container.encode(takendownRecordCount, forKey: .takendownRecordCount)

            try container.encode(labeledAccountCount, forKey: .labeledAccountCount)

            try container.encode(labeledRecordCount, forKey: .labeledRecordCount)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(accountReportCount)
            hasher.combine(recordReportCount)
            hasher.combine(reportedAccountCount)
            hasher.combine(reportedRecordCount)
            hasher.combine(takendownAccountCount)
            hasher.combine(takendownRecordCount)
            hasher.combine(labeledAccountCount)
            hasher.combine(labeledRecordCount)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if did != other.did {
                return false
            }

            if accountReportCount != other.accountReportCount {
                return false
            }

            if recordReportCount != other.recordReportCount {
                return false
            }

            if reportedAccountCount != other.reportedAccountCount {
                return false
            }

            if reportedRecordCount != other.reportedRecordCount {
                return false
            }

            if takendownAccountCount != other.takendownAccountCount {
                return false
            }

            if takendownRecordCount != other.takendownRecordCount {
                return false
            }

            if labeledAccountCount != other.labeledAccountCount {
                return false
            }

            if labeledRecordCount != other.labeledRecordCount {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            let accountReportCountValue = try (accountReportCount as? DAGCBOREncodable)?.toCBORValue() ?? accountReportCount
            map = map.adding(key: "accountReportCount", value: accountReportCountValue)

            let recordReportCountValue = try (recordReportCount as? DAGCBOREncodable)?.toCBORValue() ?? recordReportCount
            map = map.adding(key: "recordReportCount", value: recordReportCountValue)

            let reportedAccountCountValue = try (reportedAccountCount as? DAGCBOREncodable)?.toCBORValue() ?? reportedAccountCount
            map = map.adding(key: "reportedAccountCount", value: reportedAccountCountValue)

            let reportedRecordCountValue = try (reportedRecordCount as? DAGCBOREncodable)?.toCBORValue() ?? reportedRecordCount
            map = map.adding(key: "reportedRecordCount", value: reportedRecordCountValue)

            let takendownAccountCountValue = try (takendownAccountCount as? DAGCBOREncodable)?.toCBORValue() ?? takendownAccountCount
            map = map.adding(key: "takendownAccountCount", value: takendownAccountCountValue)

            let takendownRecordCountValue = try (takendownRecordCount as? DAGCBOREncodable)?.toCBORValue() ?? takendownRecordCount
            map = map.adding(key: "takendownRecordCount", value: takendownRecordCountValue)

            let labeledAccountCountValue = try (labeledAccountCount as? DAGCBOREncodable)?.toCBORValue() ?? labeledAccountCount
            map = map.adding(key: "labeledAccountCount", value: labeledAccountCountValue)

            let labeledRecordCountValue = try (labeledRecordCount as? DAGCBOREncodable)?.toCBORValue() ?? labeledRecordCount
            map = map.adding(key: "labeledRecordCount", value: labeledRecordCountValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case accountReportCount
            case recordReportCount
            case reportedAccountCount
            case reportedRecordCount
            case takendownAccountCount
            case takendownRecordCount
            case labeledAccountCount
            case labeledRecordCount
        }
    }

    public enum ModEventViewEventUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case toolsOzoneModerationDefsModEventTakedown(ToolsOzoneModerationDefs.ModEventTakedown)
        case toolsOzoneModerationDefsModEventReverseTakedown(ToolsOzoneModerationDefs.ModEventReverseTakedown)
        case toolsOzoneModerationDefsModEventComment(ToolsOzoneModerationDefs.ModEventComment)
        case toolsOzoneModerationDefsModEventReport(ToolsOzoneModerationDefs.ModEventReport)
        case toolsOzoneModerationDefsModEventLabel(ToolsOzoneModerationDefs.ModEventLabel)
        case toolsOzoneModerationDefsModEventAcknowledge(ToolsOzoneModerationDefs.ModEventAcknowledge)
        case toolsOzoneModerationDefsModEventEscalate(ToolsOzoneModerationDefs.ModEventEscalate)
        case toolsOzoneModerationDefsModEventMute(ToolsOzoneModerationDefs.ModEventMute)
        case toolsOzoneModerationDefsModEventUnmute(ToolsOzoneModerationDefs.ModEventUnmute)
        case toolsOzoneModerationDefsModEventMuteReporter(ToolsOzoneModerationDefs.ModEventMuteReporter)
        case toolsOzoneModerationDefsModEventUnmuteReporter(ToolsOzoneModerationDefs.ModEventUnmuteReporter)
        case toolsOzoneModerationDefsModEventEmail(ToolsOzoneModerationDefs.ModEventEmail)
        case toolsOzoneModerationDefsModEventResolveAppeal(ToolsOzoneModerationDefs.ModEventResolveAppeal)
        case toolsOzoneModerationDefsModEventDivert(ToolsOzoneModerationDefs.ModEventDivert)
        case toolsOzoneModerationDefsModEventTag(ToolsOzoneModerationDefs.ModEventTag)
        case toolsOzoneModerationDefsAccountEvent(ToolsOzoneModerationDefs.AccountEvent)
        case toolsOzoneModerationDefsIdentityEvent(ToolsOzoneModerationDefs.IdentityEvent)
        case toolsOzoneModerationDefsRecordEvent(ToolsOzoneModerationDefs.RecordEvent)
        case toolsOzoneModerationDefsModEventPriorityScore(ToolsOzoneModerationDefs.ModEventPriorityScore)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ToolsOzoneModerationDefs.ModEventTakedown) {
            self = .toolsOzoneModerationDefsModEventTakedown(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventReverseTakedown) {
            self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventComment) {
            self = .toolsOzoneModerationDefsModEventComment(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventReport) {
            self = .toolsOzoneModerationDefsModEventReport(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventLabel) {
            self = .toolsOzoneModerationDefsModEventLabel(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventAcknowledge) {
            self = .toolsOzoneModerationDefsModEventAcknowledge(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventEscalate) {
            self = .toolsOzoneModerationDefsModEventEscalate(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventMute) {
            self = .toolsOzoneModerationDefsModEventMute(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventUnmute) {
            self = .toolsOzoneModerationDefsModEventUnmute(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventMuteReporter) {
            self = .toolsOzoneModerationDefsModEventMuteReporter(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventUnmuteReporter) {
            self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventEmail) {
            self = .toolsOzoneModerationDefsModEventEmail(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventResolveAppeal) {
            self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventDivert) {
            self = .toolsOzoneModerationDefsModEventDivert(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventTag) {
            self = .toolsOzoneModerationDefsModEventTag(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.AccountEvent) {
            self = .toolsOzoneModerationDefsAccountEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.IdentityEvent) {
            self = .toolsOzoneModerationDefsIdentityEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.RecordEvent) {
            self = .toolsOzoneModerationDefsRecordEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventPriorityScore) {
            self = .toolsOzoneModerationDefsModEventPriorityScore(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "tools.ozone.moderation.defs#modEventTakedown":
                let value = try ToolsOzoneModerationDefs.ModEventTakedown(from: decoder)
                self = .toolsOzoneModerationDefsModEventTakedown(value)
            case "tools.ozone.moderation.defs#modEventReverseTakedown":
                let value = try ToolsOzoneModerationDefs.ModEventReverseTakedown(from: decoder)
                self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
            case "tools.ozone.moderation.defs#modEventComment":
                let value = try ToolsOzoneModerationDefs.ModEventComment(from: decoder)
                self = .toolsOzoneModerationDefsModEventComment(value)
            case "tools.ozone.moderation.defs#modEventReport":
                let value = try ToolsOzoneModerationDefs.ModEventReport(from: decoder)
                self = .toolsOzoneModerationDefsModEventReport(value)
            case "tools.ozone.moderation.defs#modEventLabel":
                let value = try ToolsOzoneModerationDefs.ModEventLabel(from: decoder)
                self = .toolsOzoneModerationDefsModEventLabel(value)
            case "tools.ozone.moderation.defs#modEventAcknowledge":
                let value = try ToolsOzoneModerationDefs.ModEventAcknowledge(from: decoder)
                self = .toolsOzoneModerationDefsModEventAcknowledge(value)
            case "tools.ozone.moderation.defs#modEventEscalate":
                let value = try ToolsOzoneModerationDefs.ModEventEscalate(from: decoder)
                self = .toolsOzoneModerationDefsModEventEscalate(value)
            case "tools.ozone.moderation.defs#modEventMute":
                let value = try ToolsOzoneModerationDefs.ModEventMute(from: decoder)
                self = .toolsOzoneModerationDefsModEventMute(value)
            case "tools.ozone.moderation.defs#modEventUnmute":
                let value = try ToolsOzoneModerationDefs.ModEventUnmute(from: decoder)
                self = .toolsOzoneModerationDefsModEventUnmute(value)
            case "tools.ozone.moderation.defs#modEventMuteReporter":
                let value = try ToolsOzoneModerationDefs.ModEventMuteReporter(from: decoder)
                self = .toolsOzoneModerationDefsModEventMuteReporter(value)
            case "tools.ozone.moderation.defs#modEventUnmuteReporter":
                let value = try ToolsOzoneModerationDefs.ModEventUnmuteReporter(from: decoder)
                self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
            case "tools.ozone.moderation.defs#modEventEmail":
                let value = try ToolsOzoneModerationDefs.ModEventEmail(from: decoder)
                self = .toolsOzoneModerationDefsModEventEmail(value)
            case "tools.ozone.moderation.defs#modEventResolveAppeal":
                let value = try ToolsOzoneModerationDefs.ModEventResolveAppeal(from: decoder)
                self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
            case "tools.ozone.moderation.defs#modEventDivert":
                let value = try ToolsOzoneModerationDefs.ModEventDivert(from: decoder)
                self = .toolsOzoneModerationDefsModEventDivert(value)
            case "tools.ozone.moderation.defs#modEventTag":
                let value = try ToolsOzoneModerationDefs.ModEventTag(from: decoder)
                self = .toolsOzoneModerationDefsModEventTag(value)
            case "tools.ozone.moderation.defs#accountEvent":
                let value = try ToolsOzoneModerationDefs.AccountEvent(from: decoder)
                self = .toolsOzoneModerationDefsAccountEvent(value)
            case "tools.ozone.moderation.defs#identityEvent":
                let value = try ToolsOzoneModerationDefs.IdentityEvent(from: decoder)
                self = .toolsOzoneModerationDefsIdentityEvent(value)
            case "tools.ozone.moderation.defs#recordEvent":
                let value = try ToolsOzoneModerationDefs.RecordEvent(from: decoder)
                self = .toolsOzoneModerationDefsRecordEvent(value)
            case "tools.ozone.moderation.defs#modEventPriorityScore":
                let value = try ToolsOzoneModerationDefs.ModEventPriorityScore(from: decoder)
                self = .toolsOzoneModerationDefsModEventPriorityScore(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                try container.encode("tools.ozone.moderation.defs#modEventTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                try container.encode("tools.ozone.moderation.defs#modEventReverseTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventComment(value):
                try container.encode("tools.ozone.moderation.defs#modEventComment", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReport(value):
                try container.encode("tools.ozone.moderation.defs#modEventReport", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventLabel(value):
                try container.encode("tools.ozone.moderation.defs#modEventLabel", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                try container.encode("tools.ozone.moderation.defs#modEventAcknowledge", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                try container.encode("tools.ozone.moderation.defs#modEventEscalate", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMute(value):
                try container.encode("tools.ozone.moderation.defs#modEventMute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                try container.encode("tools.ozone.moderation.defs#modEventUnmute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                try container.encode("tools.ozone.moderation.defs#modEventMuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                try container.encode("tools.ozone.moderation.defs#modEventUnmuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEmail(value):
                try container.encode("tools.ozone.moderation.defs#modEventEmail", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                try container.encode("tools.ozone.moderation.defs#modEventResolveAppeal", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventDivert(value):
                try container.encode("tools.ozone.moderation.defs#modEventDivert", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventTag(value):
                try container.encode("tools.ozone.moderation.defs#modEventTag", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsAccountEvent(value):
                try container.encode("tools.ozone.moderation.defs#accountEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                try container.encode("tools.ozone.moderation.defs#identityEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRecordEvent(value):
                try container.encode("tools.ozone.moderation.defs#recordEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                try container.encode("tools.ozone.moderation.defs#modEventPriorityScore", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                hasher.combine("tools.ozone.moderation.defs#modEventTakedown")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                hasher.combine("tools.ozone.moderation.defs#modEventReverseTakedown")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventComment(value):
                hasher.combine("tools.ozone.moderation.defs#modEventComment")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventReport(value):
                hasher.combine("tools.ozone.moderation.defs#modEventReport")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventLabel(value):
                hasher.combine("tools.ozone.moderation.defs#modEventLabel")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                hasher.combine("tools.ozone.moderation.defs#modEventAcknowledge")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                hasher.combine("tools.ozone.moderation.defs#modEventEscalate")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventMute(value):
                hasher.combine("tools.ozone.moderation.defs#modEventMute")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                hasher.combine("tools.ozone.moderation.defs#modEventUnmute")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                hasher.combine("tools.ozone.moderation.defs#modEventMuteReporter")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                hasher.combine("tools.ozone.moderation.defs#modEventUnmuteReporter")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventEmail(value):
                hasher.combine("tools.ozone.moderation.defs#modEventEmail")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                hasher.combine("tools.ozone.moderation.defs#modEventResolveAppeal")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventDivert(value):
                hasher.combine("tools.ozone.moderation.defs#modEventDivert")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventTag(value):
                hasher.combine("tools.ozone.moderation.defs#modEventTag")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsAccountEvent(value):
                hasher.combine("tools.ozone.moderation.defs#accountEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                hasher.combine("tools.ozone.moderation.defs#identityEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsRecordEvent(value):
                hasher.combine("tools.ozone.moderation.defs#recordEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                hasher.combine("tools.ozone.moderation.defs#modEventPriorityScore")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ModEventViewEventUnion, rhs: ModEventViewEventUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .toolsOzoneModerationDefsModEventTakedown(lhsValue),
                .toolsOzoneModerationDefsModEventTakedown(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventReverseTakedown(lhsValue),
                .toolsOzoneModerationDefsModEventReverseTakedown(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventComment(lhsValue),
                .toolsOzoneModerationDefsModEventComment(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventReport(lhsValue),
                .toolsOzoneModerationDefsModEventReport(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventLabel(lhsValue),
                .toolsOzoneModerationDefsModEventLabel(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventAcknowledge(lhsValue),
                .toolsOzoneModerationDefsModEventAcknowledge(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventEscalate(lhsValue),
                .toolsOzoneModerationDefsModEventEscalate(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventMute(lhsValue),
                .toolsOzoneModerationDefsModEventMute(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventUnmute(lhsValue),
                .toolsOzoneModerationDefsModEventUnmute(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventMuteReporter(lhsValue),
                .toolsOzoneModerationDefsModEventMuteReporter(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventUnmuteReporter(lhsValue),
                .toolsOzoneModerationDefsModEventUnmuteReporter(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventEmail(lhsValue),
                .toolsOzoneModerationDefsModEventEmail(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventResolveAppeal(lhsValue),
                .toolsOzoneModerationDefsModEventResolveAppeal(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventDivert(lhsValue),
                .toolsOzoneModerationDefsModEventDivert(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventTag(lhsValue),
                .toolsOzoneModerationDefsModEventTag(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsAccountEvent(lhsValue),
                .toolsOzoneModerationDefsAccountEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsIdentityEvent(lhsValue),
                .toolsOzoneModerationDefsIdentityEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsRecordEvent(lhsValue),
                .toolsOzoneModerationDefsRecordEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventPriorityScore(lhsValue),
                .toolsOzoneModerationDefsModEventPriorityScore(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ModEventViewEventUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventTakedown")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventReverseTakedown")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventComment(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventComment")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventReport(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventReport")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventLabel(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventLabel")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventAcknowledge")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventEscalate")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventMute(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventMute")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventUnmute")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventMuteReporter")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventUnmuteReporter")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventEmail(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventEmail")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventResolveAppeal")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventDivert(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventDivert")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventTag(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventTag")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsAccountEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#accountEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#identityEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsRecordEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#recordEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventPriorityScore")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventComment(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventReport(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventLabel(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventMute(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventEmail(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventDivert(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventTag(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsAccountEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsRecordEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsModEventTakedown(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventTakedown(value)
            case var .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
            case var .toolsOzoneModerationDefsModEventComment(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventComment(value)
            case var .toolsOzoneModerationDefsModEventReport(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventReport(value)
            case var .toolsOzoneModerationDefsModEventLabel(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventLabel(value)
            case var .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventAcknowledge(value)
            case var .toolsOzoneModerationDefsModEventEscalate(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventEscalate(value)
            case var .toolsOzoneModerationDefsModEventMute(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventMute(value)
            case var .toolsOzoneModerationDefsModEventUnmute(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventUnmute(value)
            case var .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventMuteReporter(value)
            case var .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
            case var .toolsOzoneModerationDefsModEventEmail(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventEmail(value)
            case var .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
            case var .toolsOzoneModerationDefsModEventDivert(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventDivert(value)
            case var .toolsOzoneModerationDefsModEventTag(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventTag(value)
            case var .toolsOzoneModerationDefsAccountEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsAccountEvent(value)
            case var .toolsOzoneModerationDefsIdentityEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsIdentityEvent(value)
            case var .toolsOzoneModerationDefsRecordEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRecordEvent(value)
            case var .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventPriorityScore(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ModEventViewSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case chatBskyConvoDefsMessageRef(ChatBskyConvoDefs.MessageRef)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ComAtprotoAdminDefs.RepoRef) {
            self = .comAtprotoAdminDefsRepoRef(value)
        }

        public init(_ value: ComAtprotoRepoStrongRef) {
            self = .comAtprotoRepoStrongRef(value)
        }

        public init(_ value: ChatBskyConvoDefs.MessageRef) {
            self = .chatBskyConvoDefsMessageRef(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "com.atproto.admin.defs#repoRef":
                let value = try ComAtprotoAdminDefs.RepoRef(from: decoder)
                self = .comAtprotoAdminDefsRepoRef(value)
            case "com.atproto.repo.strongRef":
                let value = try ComAtprotoRepoStrongRef(from: decoder)
                self = .comAtprotoRepoStrongRef(value)
            case "chat.bsky.convo.defs#messageRef":
                let value = try ChatBskyConvoDefs.MessageRef(from: decoder)
                self = .chatBskyConvoDefsMessageRef(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoStrongRef(value):
                try container.encode("com.atproto.repo.strongRef", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsMessageRef(value):
                try container.encode("chat.bsky.convo.defs#messageRef", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                hasher.combine("com.atproto.admin.defs#repoRef")
                hasher.combine(value)
            case let .comAtprotoRepoStrongRef(value):
                hasher.combine("com.atproto.repo.strongRef")
                hasher.combine(value)
            case let .chatBskyConvoDefsMessageRef(value):
                hasher.combine("chat.bsky.convo.defs#messageRef")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ModEventViewSubjectUnion, rhs: ModEventViewSubjectUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .comAtprotoAdminDefsRepoRef(lhsValue),
                .comAtprotoAdminDefsRepoRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoRepoStrongRef(lhsValue),
                .comAtprotoRepoStrongRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsMessageRef(lhsValue),
                .chatBskyConvoDefsMessageRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ModEventViewSubjectUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoRef")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .comAtprotoRepoStrongRef(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "com.atproto.repo.strongRef")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .chatBskyConvoDefsMessageRef(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageRef")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                return value.hasPendingData
            case let .comAtprotoRepoStrongRef(value):
                return value.hasPendingData
            case let .chatBskyConvoDefsMessageRef(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .comAtprotoAdminDefsRepoRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .comAtprotoAdminDefsRepoRef(value)
            case var .comAtprotoRepoStrongRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .comAtprotoRepoStrongRef(value)
            case var .chatBskyConvoDefsMessageRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .chatBskyConvoDefsMessageRef(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ModEventViewDetailEventUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case toolsOzoneModerationDefsModEventTakedown(ToolsOzoneModerationDefs.ModEventTakedown)
        case toolsOzoneModerationDefsModEventReverseTakedown(ToolsOzoneModerationDefs.ModEventReverseTakedown)
        case toolsOzoneModerationDefsModEventComment(ToolsOzoneModerationDefs.ModEventComment)
        case toolsOzoneModerationDefsModEventReport(ToolsOzoneModerationDefs.ModEventReport)
        case toolsOzoneModerationDefsModEventLabel(ToolsOzoneModerationDefs.ModEventLabel)
        case toolsOzoneModerationDefsModEventAcknowledge(ToolsOzoneModerationDefs.ModEventAcknowledge)
        case toolsOzoneModerationDefsModEventEscalate(ToolsOzoneModerationDefs.ModEventEscalate)
        case toolsOzoneModerationDefsModEventMute(ToolsOzoneModerationDefs.ModEventMute)
        case toolsOzoneModerationDefsModEventUnmute(ToolsOzoneModerationDefs.ModEventUnmute)
        case toolsOzoneModerationDefsModEventMuteReporter(ToolsOzoneModerationDefs.ModEventMuteReporter)
        case toolsOzoneModerationDefsModEventUnmuteReporter(ToolsOzoneModerationDefs.ModEventUnmuteReporter)
        case toolsOzoneModerationDefsModEventEmail(ToolsOzoneModerationDefs.ModEventEmail)
        case toolsOzoneModerationDefsModEventResolveAppeal(ToolsOzoneModerationDefs.ModEventResolveAppeal)
        case toolsOzoneModerationDefsModEventDivert(ToolsOzoneModerationDefs.ModEventDivert)
        case toolsOzoneModerationDefsModEventTag(ToolsOzoneModerationDefs.ModEventTag)
        case toolsOzoneModerationDefsAccountEvent(ToolsOzoneModerationDefs.AccountEvent)
        case toolsOzoneModerationDefsIdentityEvent(ToolsOzoneModerationDefs.IdentityEvent)
        case toolsOzoneModerationDefsRecordEvent(ToolsOzoneModerationDefs.RecordEvent)
        case toolsOzoneModerationDefsModEventPriorityScore(ToolsOzoneModerationDefs.ModEventPriorityScore)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ToolsOzoneModerationDefs.ModEventTakedown) {
            self = .toolsOzoneModerationDefsModEventTakedown(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventReverseTakedown) {
            self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventComment) {
            self = .toolsOzoneModerationDefsModEventComment(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventReport) {
            self = .toolsOzoneModerationDefsModEventReport(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventLabel) {
            self = .toolsOzoneModerationDefsModEventLabel(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventAcknowledge) {
            self = .toolsOzoneModerationDefsModEventAcknowledge(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventEscalate) {
            self = .toolsOzoneModerationDefsModEventEscalate(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventMute) {
            self = .toolsOzoneModerationDefsModEventMute(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventUnmute) {
            self = .toolsOzoneModerationDefsModEventUnmute(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventMuteReporter) {
            self = .toolsOzoneModerationDefsModEventMuteReporter(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventUnmuteReporter) {
            self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventEmail) {
            self = .toolsOzoneModerationDefsModEventEmail(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventResolveAppeal) {
            self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventDivert) {
            self = .toolsOzoneModerationDefsModEventDivert(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventTag) {
            self = .toolsOzoneModerationDefsModEventTag(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.AccountEvent) {
            self = .toolsOzoneModerationDefsAccountEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.IdentityEvent) {
            self = .toolsOzoneModerationDefsIdentityEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.RecordEvent) {
            self = .toolsOzoneModerationDefsRecordEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventPriorityScore) {
            self = .toolsOzoneModerationDefsModEventPriorityScore(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "tools.ozone.moderation.defs#modEventTakedown":
                let value = try ToolsOzoneModerationDefs.ModEventTakedown(from: decoder)
                self = .toolsOzoneModerationDefsModEventTakedown(value)
            case "tools.ozone.moderation.defs#modEventReverseTakedown":
                let value = try ToolsOzoneModerationDefs.ModEventReverseTakedown(from: decoder)
                self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
            case "tools.ozone.moderation.defs#modEventComment":
                let value = try ToolsOzoneModerationDefs.ModEventComment(from: decoder)
                self = .toolsOzoneModerationDefsModEventComment(value)
            case "tools.ozone.moderation.defs#modEventReport":
                let value = try ToolsOzoneModerationDefs.ModEventReport(from: decoder)
                self = .toolsOzoneModerationDefsModEventReport(value)
            case "tools.ozone.moderation.defs#modEventLabel":
                let value = try ToolsOzoneModerationDefs.ModEventLabel(from: decoder)
                self = .toolsOzoneModerationDefsModEventLabel(value)
            case "tools.ozone.moderation.defs#modEventAcknowledge":
                let value = try ToolsOzoneModerationDefs.ModEventAcknowledge(from: decoder)
                self = .toolsOzoneModerationDefsModEventAcknowledge(value)
            case "tools.ozone.moderation.defs#modEventEscalate":
                let value = try ToolsOzoneModerationDefs.ModEventEscalate(from: decoder)
                self = .toolsOzoneModerationDefsModEventEscalate(value)
            case "tools.ozone.moderation.defs#modEventMute":
                let value = try ToolsOzoneModerationDefs.ModEventMute(from: decoder)
                self = .toolsOzoneModerationDefsModEventMute(value)
            case "tools.ozone.moderation.defs#modEventUnmute":
                let value = try ToolsOzoneModerationDefs.ModEventUnmute(from: decoder)
                self = .toolsOzoneModerationDefsModEventUnmute(value)
            case "tools.ozone.moderation.defs#modEventMuteReporter":
                let value = try ToolsOzoneModerationDefs.ModEventMuteReporter(from: decoder)
                self = .toolsOzoneModerationDefsModEventMuteReporter(value)
            case "tools.ozone.moderation.defs#modEventUnmuteReporter":
                let value = try ToolsOzoneModerationDefs.ModEventUnmuteReporter(from: decoder)
                self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
            case "tools.ozone.moderation.defs#modEventEmail":
                let value = try ToolsOzoneModerationDefs.ModEventEmail(from: decoder)
                self = .toolsOzoneModerationDefsModEventEmail(value)
            case "tools.ozone.moderation.defs#modEventResolveAppeal":
                let value = try ToolsOzoneModerationDefs.ModEventResolveAppeal(from: decoder)
                self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
            case "tools.ozone.moderation.defs#modEventDivert":
                let value = try ToolsOzoneModerationDefs.ModEventDivert(from: decoder)
                self = .toolsOzoneModerationDefsModEventDivert(value)
            case "tools.ozone.moderation.defs#modEventTag":
                let value = try ToolsOzoneModerationDefs.ModEventTag(from: decoder)
                self = .toolsOzoneModerationDefsModEventTag(value)
            case "tools.ozone.moderation.defs#accountEvent":
                let value = try ToolsOzoneModerationDefs.AccountEvent(from: decoder)
                self = .toolsOzoneModerationDefsAccountEvent(value)
            case "tools.ozone.moderation.defs#identityEvent":
                let value = try ToolsOzoneModerationDefs.IdentityEvent(from: decoder)
                self = .toolsOzoneModerationDefsIdentityEvent(value)
            case "tools.ozone.moderation.defs#recordEvent":
                let value = try ToolsOzoneModerationDefs.RecordEvent(from: decoder)
                self = .toolsOzoneModerationDefsRecordEvent(value)
            case "tools.ozone.moderation.defs#modEventPriorityScore":
                let value = try ToolsOzoneModerationDefs.ModEventPriorityScore(from: decoder)
                self = .toolsOzoneModerationDefsModEventPriorityScore(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                try container.encode("tools.ozone.moderation.defs#modEventTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                try container.encode("tools.ozone.moderation.defs#modEventReverseTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventComment(value):
                try container.encode("tools.ozone.moderation.defs#modEventComment", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReport(value):
                try container.encode("tools.ozone.moderation.defs#modEventReport", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventLabel(value):
                try container.encode("tools.ozone.moderation.defs#modEventLabel", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                try container.encode("tools.ozone.moderation.defs#modEventAcknowledge", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                try container.encode("tools.ozone.moderation.defs#modEventEscalate", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMute(value):
                try container.encode("tools.ozone.moderation.defs#modEventMute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                try container.encode("tools.ozone.moderation.defs#modEventUnmute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                try container.encode("tools.ozone.moderation.defs#modEventMuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                try container.encode("tools.ozone.moderation.defs#modEventUnmuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEmail(value):
                try container.encode("tools.ozone.moderation.defs#modEventEmail", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                try container.encode("tools.ozone.moderation.defs#modEventResolveAppeal", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventDivert(value):
                try container.encode("tools.ozone.moderation.defs#modEventDivert", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventTag(value):
                try container.encode("tools.ozone.moderation.defs#modEventTag", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsAccountEvent(value):
                try container.encode("tools.ozone.moderation.defs#accountEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                try container.encode("tools.ozone.moderation.defs#identityEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRecordEvent(value):
                try container.encode("tools.ozone.moderation.defs#recordEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                try container.encode("tools.ozone.moderation.defs#modEventPriorityScore", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                hasher.combine("tools.ozone.moderation.defs#modEventTakedown")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                hasher.combine("tools.ozone.moderation.defs#modEventReverseTakedown")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventComment(value):
                hasher.combine("tools.ozone.moderation.defs#modEventComment")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventReport(value):
                hasher.combine("tools.ozone.moderation.defs#modEventReport")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventLabel(value):
                hasher.combine("tools.ozone.moderation.defs#modEventLabel")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                hasher.combine("tools.ozone.moderation.defs#modEventAcknowledge")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                hasher.combine("tools.ozone.moderation.defs#modEventEscalate")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventMute(value):
                hasher.combine("tools.ozone.moderation.defs#modEventMute")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                hasher.combine("tools.ozone.moderation.defs#modEventUnmute")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                hasher.combine("tools.ozone.moderation.defs#modEventMuteReporter")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                hasher.combine("tools.ozone.moderation.defs#modEventUnmuteReporter")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventEmail(value):
                hasher.combine("tools.ozone.moderation.defs#modEventEmail")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                hasher.combine("tools.ozone.moderation.defs#modEventResolveAppeal")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventDivert(value):
                hasher.combine("tools.ozone.moderation.defs#modEventDivert")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventTag(value):
                hasher.combine("tools.ozone.moderation.defs#modEventTag")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsAccountEvent(value):
                hasher.combine("tools.ozone.moderation.defs#accountEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                hasher.combine("tools.ozone.moderation.defs#identityEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsRecordEvent(value):
                hasher.combine("tools.ozone.moderation.defs#recordEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                hasher.combine("tools.ozone.moderation.defs#modEventPriorityScore")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ModEventViewDetailEventUnion, rhs: ModEventViewDetailEventUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .toolsOzoneModerationDefsModEventTakedown(lhsValue),
                .toolsOzoneModerationDefsModEventTakedown(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventReverseTakedown(lhsValue),
                .toolsOzoneModerationDefsModEventReverseTakedown(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventComment(lhsValue),
                .toolsOzoneModerationDefsModEventComment(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventReport(lhsValue),
                .toolsOzoneModerationDefsModEventReport(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventLabel(lhsValue),
                .toolsOzoneModerationDefsModEventLabel(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventAcknowledge(lhsValue),
                .toolsOzoneModerationDefsModEventAcknowledge(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventEscalate(lhsValue),
                .toolsOzoneModerationDefsModEventEscalate(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventMute(lhsValue),
                .toolsOzoneModerationDefsModEventMute(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventUnmute(lhsValue),
                .toolsOzoneModerationDefsModEventUnmute(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventMuteReporter(lhsValue),
                .toolsOzoneModerationDefsModEventMuteReporter(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventUnmuteReporter(lhsValue),
                .toolsOzoneModerationDefsModEventUnmuteReporter(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventEmail(lhsValue),
                .toolsOzoneModerationDefsModEventEmail(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventResolveAppeal(lhsValue),
                .toolsOzoneModerationDefsModEventResolveAppeal(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventDivert(lhsValue),
                .toolsOzoneModerationDefsModEventDivert(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventTag(lhsValue),
                .toolsOzoneModerationDefsModEventTag(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsAccountEvent(lhsValue),
                .toolsOzoneModerationDefsAccountEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsIdentityEvent(lhsValue),
                .toolsOzoneModerationDefsIdentityEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsRecordEvent(lhsValue),
                .toolsOzoneModerationDefsRecordEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventPriorityScore(lhsValue),
                .toolsOzoneModerationDefsModEventPriorityScore(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ModEventViewDetailEventUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventTakedown")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventReverseTakedown")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventComment(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventComment")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventReport(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventReport")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventLabel(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventLabel")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventAcknowledge")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventEscalate")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventMute(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventMute")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventUnmute")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventMuteReporter")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventUnmuteReporter")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventEmail(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventEmail")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventResolveAppeal")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventDivert(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventDivert")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventTag(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventTag")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsAccountEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#accountEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#identityEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsRecordEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#recordEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventPriorityScore")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventComment(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventReport(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventLabel(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventMute(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventEmail(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventDivert(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventTag(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsAccountEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsRecordEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsModEventTakedown(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventTakedown(value)
            case var .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
            case var .toolsOzoneModerationDefsModEventComment(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventComment(value)
            case var .toolsOzoneModerationDefsModEventReport(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventReport(value)
            case var .toolsOzoneModerationDefsModEventLabel(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventLabel(value)
            case var .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventAcknowledge(value)
            case var .toolsOzoneModerationDefsModEventEscalate(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventEscalate(value)
            case var .toolsOzoneModerationDefsModEventMute(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventMute(value)
            case var .toolsOzoneModerationDefsModEventUnmute(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventUnmute(value)
            case var .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventMuteReporter(value)
            case var .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
            case var .toolsOzoneModerationDefsModEventEmail(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventEmail(value)
            case var .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
            case var .toolsOzoneModerationDefsModEventDivert(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventDivert(value)
            case var .toolsOzoneModerationDefsModEventTag(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventTag(value)
            case var .toolsOzoneModerationDefsAccountEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsAccountEvent(value)
            case var .toolsOzoneModerationDefsIdentityEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsIdentityEvent(value)
            case var .toolsOzoneModerationDefsRecordEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRecordEvent(value)
            case var .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventPriorityScore(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ModEventViewDetailSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case toolsOzoneModerationDefsRepoView(ToolsOzoneModerationDefs.RepoView)
        case toolsOzoneModerationDefsRepoViewNotFound(ToolsOzoneModerationDefs.RepoViewNotFound)
        case toolsOzoneModerationDefsRecordView(ToolsOzoneModerationDefs.RecordView)
        case toolsOzoneModerationDefsRecordViewNotFound(ToolsOzoneModerationDefs.RecordViewNotFound)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ToolsOzoneModerationDefs.RepoView) {
            self = .toolsOzoneModerationDefsRepoView(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.RepoViewNotFound) {
            self = .toolsOzoneModerationDefsRepoViewNotFound(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.RecordView) {
            self = .toolsOzoneModerationDefsRecordView(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.RecordViewNotFound) {
            self = .toolsOzoneModerationDefsRecordViewNotFound(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "tools.ozone.moderation.defs#repoView":
                let value = try ToolsOzoneModerationDefs.RepoView(from: decoder)
                self = .toolsOzoneModerationDefsRepoView(value)
            case "tools.ozone.moderation.defs#repoViewNotFound":
                let value = try ToolsOzoneModerationDefs.RepoViewNotFound(from: decoder)
                self = .toolsOzoneModerationDefsRepoViewNotFound(value)
            case "tools.ozone.moderation.defs#recordView":
                let value = try ToolsOzoneModerationDefs.RecordView(from: decoder)
                self = .toolsOzoneModerationDefsRecordView(value)
            case "tools.ozone.moderation.defs#recordViewNotFound":
                let value = try ToolsOzoneModerationDefs.RecordViewNotFound(from: decoder)
                self = .toolsOzoneModerationDefsRecordViewNotFound(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsRepoView(value):
                try container.encode("tools.ozone.moderation.defs#repoView", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                try container.encode("tools.ozone.moderation.defs#repoViewNotFound", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRecordView(value):
                try container.encode("tools.ozone.moderation.defs#recordView", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRecordViewNotFound(value):
                try container.encode("tools.ozone.moderation.defs#recordViewNotFound", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .toolsOzoneModerationDefsRepoView(value):
                hasher.combine("tools.ozone.moderation.defs#repoView")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                hasher.combine("tools.ozone.moderation.defs#repoViewNotFound")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsRecordView(value):
                hasher.combine("tools.ozone.moderation.defs#recordView")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsRecordViewNotFound(value):
                hasher.combine("tools.ozone.moderation.defs#recordViewNotFound")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ModEventViewDetailSubjectUnion, rhs: ModEventViewDetailSubjectUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .toolsOzoneModerationDefsRepoView(lhsValue),
                .toolsOzoneModerationDefsRepoView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsRepoViewNotFound(lhsValue),
                .toolsOzoneModerationDefsRepoViewNotFound(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsRecordView(lhsValue),
                .toolsOzoneModerationDefsRecordView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsRecordViewNotFound(lhsValue),
                .toolsOzoneModerationDefsRecordViewNotFound(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ModEventViewDetailSubjectUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .toolsOzoneModerationDefsRepoView(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#repoView")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#repoViewNotFound")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsRecordView(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#recordView")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsRecordViewNotFound(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#recordViewNotFound")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsRepoView(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsRecordView(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsRecordViewNotFound(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsRepoView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRepoView(value)
            case var .toolsOzoneModerationDefsRepoViewNotFound(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRepoViewNotFound(value)
            case var .toolsOzoneModerationDefsRecordView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRecordView(value)
            case var .toolsOzoneModerationDefsRecordViewNotFound(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRecordViewNotFound(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum SubjectStatusViewSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ComAtprotoAdminDefs.RepoRef) {
            self = .comAtprotoAdminDefsRepoRef(value)
        }

        public init(_ value: ComAtprotoRepoStrongRef) {
            self = .comAtprotoRepoStrongRef(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "com.atproto.admin.defs#repoRef":
                let value = try ComAtprotoAdminDefs.RepoRef(from: decoder)
                self = .comAtprotoAdminDefsRepoRef(value)
            case "com.atproto.repo.strongRef":
                let value = try ComAtprotoRepoStrongRef(from: decoder)
                self = .comAtprotoRepoStrongRef(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoStrongRef(value):
                try container.encode("com.atproto.repo.strongRef", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                hasher.combine("com.atproto.admin.defs#repoRef")
                hasher.combine(value)
            case let .comAtprotoRepoStrongRef(value):
                hasher.combine("com.atproto.repo.strongRef")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: SubjectStatusViewSubjectUnion, rhs: SubjectStatusViewSubjectUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .comAtprotoAdminDefsRepoRef(lhsValue),
                .comAtprotoAdminDefsRepoRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoRepoStrongRef(lhsValue),
                .comAtprotoRepoStrongRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? SubjectStatusViewSubjectUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoRef")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .comAtprotoRepoStrongRef(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "com.atproto.repo.strongRef")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                return value.hasPendingData
            case let .comAtprotoRepoStrongRef(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .comAtprotoAdminDefsRepoRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .comAtprotoAdminDefsRepoRef(value)
            case var .comAtprotoRepoStrongRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .comAtprotoRepoStrongRef(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum SubjectStatusViewHostingUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case toolsOzoneModerationDefsAccountHosting(ToolsOzoneModerationDefs.AccountHosting)
        case toolsOzoneModerationDefsRecordHosting(ToolsOzoneModerationDefs.RecordHosting)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ToolsOzoneModerationDefs.AccountHosting) {
            self = .toolsOzoneModerationDefsAccountHosting(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.RecordHosting) {
            self = .toolsOzoneModerationDefsRecordHosting(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "tools.ozone.moderation.defs#accountHosting":
                let value = try ToolsOzoneModerationDefs.AccountHosting(from: decoder)
                self = .toolsOzoneModerationDefsAccountHosting(value)
            case "tools.ozone.moderation.defs#recordHosting":
                let value = try ToolsOzoneModerationDefs.RecordHosting(from: decoder)
                self = .toolsOzoneModerationDefsRecordHosting(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsAccountHosting(value):
                try container.encode("tools.ozone.moderation.defs#accountHosting", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRecordHosting(value):
                try container.encode("tools.ozone.moderation.defs#recordHosting", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .toolsOzoneModerationDefsAccountHosting(value):
                hasher.combine("tools.ozone.moderation.defs#accountHosting")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsRecordHosting(value):
                hasher.combine("tools.ozone.moderation.defs#recordHosting")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: SubjectStatusViewHostingUnion, rhs: SubjectStatusViewHostingUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .toolsOzoneModerationDefsAccountHosting(lhsValue),
                .toolsOzoneModerationDefsAccountHosting(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsRecordHosting(lhsValue),
                .toolsOzoneModerationDefsRecordHosting(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? SubjectStatusViewHostingUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .toolsOzoneModerationDefsAccountHosting(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#accountHosting")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsRecordHosting(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#recordHosting")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsAccountHosting(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsRecordHosting(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsAccountHosting(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsAccountHosting(value)
            case var .toolsOzoneModerationDefsRecordHosting(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRecordHosting(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum SubjectViewProfileUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: SubjectViewProfileUnion, rhs: SubjectViewProfileUnion) -> Bool {
            switch (lhs, rhs) {
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)

            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? SubjectViewProfileUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public struct SubjectReviewState: Codable, ATProtocolCodable, ATProtocolValue {
        public let rawValue: String

        // Predefined constants
        //
        public static let reviewopen = SubjectReviewState(rawValue: "#reviewOpen")
        //
        public static let reviewescalated = SubjectReviewState(rawValue: "#reviewEscalated")
        //
        public static let reviewclosed = SubjectReviewState(rawValue: "#reviewClosed")
        //
        public static let reviewnone = SubjectReviewState(rawValue: "#reviewNone")

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            rawValue = try container.decode(String.self)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? SubjectReviewState else { return false }
            return rawValue == otherValue.rawValue
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // For string-based enum types, we return the raw string value directly
            return rawValue
        }

        // Provide allCases-like functionality
        public static var predefinedValues: [SubjectReviewState] {
            return [
                .reviewopen,
                .reviewescalated,
                .reviewclosed,
                .reviewnone,
            ]
        }
    }

    public enum BlobViewDetailsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case toolsOzoneModerationDefsImageDetails(ToolsOzoneModerationDefs.ImageDetails)
        case toolsOzoneModerationDefsVideoDetails(ToolsOzoneModerationDefs.VideoDetails)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ToolsOzoneModerationDefs.ImageDetails) {
            self = .toolsOzoneModerationDefsImageDetails(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.VideoDetails) {
            self = .toolsOzoneModerationDefsVideoDetails(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "tools.ozone.moderation.defs#imageDetails":
                let value = try ToolsOzoneModerationDefs.ImageDetails(from: decoder)
                self = .toolsOzoneModerationDefsImageDetails(value)
            case "tools.ozone.moderation.defs#videoDetails":
                let value = try ToolsOzoneModerationDefs.VideoDetails(from: decoder)
                self = .toolsOzoneModerationDefsVideoDetails(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsImageDetails(value):
                try container.encode("tools.ozone.moderation.defs#imageDetails", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsVideoDetails(value):
                try container.encode("tools.ozone.moderation.defs#videoDetails", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .toolsOzoneModerationDefsImageDetails(value):
                hasher.combine("tools.ozone.moderation.defs#imageDetails")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsVideoDetails(value):
                hasher.combine("tools.ozone.moderation.defs#videoDetails")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: BlobViewDetailsUnion, rhs: BlobViewDetailsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .toolsOzoneModerationDefsImageDetails(lhsValue),
                .toolsOzoneModerationDefsImageDetails(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsVideoDetails(lhsValue),
                .toolsOzoneModerationDefsVideoDetails(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? BlobViewDetailsUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .toolsOzoneModerationDefsImageDetails(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#imageDetails")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsVideoDetails(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#videoDetails")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsImageDetails(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsVideoDetails(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsImageDetails(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsImageDetails(value)
            case var .toolsOzoneModerationDefsVideoDetails(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsVideoDetails(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}
