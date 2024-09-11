import Foundation
internal import ZippyJSON

// lexicon: 1, id: tools.ozone.moderation.defs

public struct ToolsOzoneModerationDefs {
    public static let typeIdentifier = "tools.ozone.moderation.defs"

    public struct ModEventView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventView"
        public let id: Int
        public let event: ModEventViewEventUnion
        public let subject: ModEventViewSubjectUnion
        public let subjectBlobCids: [String]
        public let createdBy: String
        public let createdAt: ATProtocolDate
        public let creatorHandle: String?
        public let subjectHandle: String?

        // Standard initializer
        public init(
            id: Int, event: ModEventViewEventUnion, subject: ModEventViewSubjectUnion, subjectBlobCids: [String], createdBy: String, createdAt: ATProtocolDate, creatorHandle: String?, subjectHandle: String?
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
                createdBy = try container.decode(String.self, forKey: .createdBy)

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
        public let createdBy: String
        public let createdAt: ATProtocolDate

        // Standard initializer
        public init(
            id: Int, event: ModEventViewDetailEventUnion, subject: ModEventViewDetailSubjectUnion, subjectBlobs: [BlobView], createdBy: String, createdAt: ATProtocolDate
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
                createdBy = try container.decode(String.self, forKey: .createdBy)

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
        public let subjectBlobCids: [String]?
        public let subjectRepoHandle: String?
        public let updatedAt: ATProtocolDate
        public let createdAt: ATProtocolDate
        public let reviewState: SubjectReviewState
        public let comment: String?
        public let muteUntil: ATProtocolDate?
        public let muteReportingUntil: ATProtocolDate?
        public let lastReviewedBy: String?
        public let lastReviewedAt: ATProtocolDate?
        public let lastReportedAt: ATProtocolDate?
        public let lastAppealedAt: ATProtocolDate?
        public let takendown: Bool?
        public let appealed: Bool?
        public let suspendUntil: ATProtocolDate?
        public let tags: [String]?

        // Standard initializer
        public init(
            id: Int, subject: SubjectStatusViewSubjectUnion, subjectBlobCids: [String]?, subjectRepoHandle: String?, updatedAt: ATProtocolDate, createdAt: ATProtocolDate, reviewState: SubjectReviewState, comment: String?, muteUntil: ATProtocolDate?, muteReportingUntil: ATProtocolDate?, lastReviewedBy: String?, lastReviewedAt: ATProtocolDate?, lastReportedAt: ATProtocolDate?, lastAppealedAt: ATProtocolDate?, takendown: Bool?, appealed: Bool?, suspendUntil: ATProtocolDate?, tags: [String]?
        ) {
            self.id = id
            self.subject = subject
            self.subjectBlobCids = subjectBlobCids
            self.subjectRepoHandle = subjectRepoHandle
            self.updatedAt = updatedAt
            self.createdAt = createdAt
            self.reviewState = reviewState
            self.comment = comment
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
                subjectBlobCids = try container.decodeIfPresent([String].self, forKey: .subjectBlobCids)

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
                lastReviewedBy = try container.decodeIfPresent(String.self, forKey: .lastReviewedBy)

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
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(id, forKey: .id)

            try container.encode(subject, forKey: .subject)

            if let value = subjectBlobCids {
                try container.encode(value, forKey: .subjectBlobCids)
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
                try container.encode(value, forKey: .tags)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(subject)
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
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if id != other.id {
                return false
            }

            if subject != other.subject {
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

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case subject
            case subjectBlobCids
            case subjectRepoHandle
            case updatedAt
            case createdAt
            case reviewState
            case comment
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
        }
    }

    public struct ModEventTakedown: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventTakedown"
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case durationInHours
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
        }
    }

    public struct ModEventComment: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventComment"
        public let comment: String
        public let sticky: Bool?

        // Standard initializer
        public init(
            comment: String, sticky: Bool?
        ) {
            self.comment = comment
            self.sticky = sticky
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                comment = try container.decode(String.self, forKey: .comment)

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

            try container.encode(comment, forKey: .comment)

            if let value = sticky {
                try container.encode(value, forKey: .sticky)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(comment)
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

        // Standard initializer
        public init(
            comment: String?, createLabelVals: [String], negateLabelVals: [String]
        ) {
            self.comment = comment
            self.createLabelVals = createLabelVals
            self.negateLabelVals = negateLabelVals
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
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = comment {
                try container.encode(value, forKey: .comment)
            }

            try container.encode(createLabelVals, forKey: .createLabelVals)

            try container.encode(negateLabelVals, forKey: .negateLabelVals)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = comment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(createLabelVals)
            hasher.combine(negateLabelVals)
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

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
            case createLabelVals
            case negateLabelVals
        }
    }

    public struct ModEventAcknowledge: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventAcknowledge"
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case comment
        }
    }

    public struct ModEventMuteReporter: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#modEventMuteReporter"
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case add
            case remove
            case comment
        }
    }

    public struct RepoView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#repoView"
        public let did: String
        public let handle: String
        public let email: String?
        public let relatedRecords: [ATProtocolValueContainer]
        public let indexedAt: ATProtocolDate
        public let moderation: Moderation
        public let invitedBy: ComAtprotoServerDefs.InviteCode?
        public let invitesDisabled: Bool?
        public let inviteNote: String?
        public let deactivatedAt: ATProtocolDate?

        // Standard initializer
        public init(
            did: String, handle: String, email: String?, relatedRecords: [ATProtocolValueContainer], indexedAt: ATProtocolDate, moderation: Moderation, invitedBy: ComAtprotoServerDefs.InviteCode?, invitesDisabled: Bool?, inviteNote: String?, deactivatedAt: ATProtocolDate?
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
                handle = try container.decode(String.self, forKey: .handle)

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

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
        }
    }

    public struct RepoViewDetail: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#repoViewDetail"
        public let did: String
        public let handle: String
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

        // Standard initializer
        public init(
            did: String, handle: String, email: String?, relatedRecords: [ATProtocolValueContainer], indexedAt: ATProtocolDate, moderation: ModerationDetail, labels: [ComAtprotoLabelDefs.Label]?, invitedBy: ComAtprotoServerDefs.InviteCode?, invites: [ComAtprotoServerDefs.InviteCode]?, invitesDisabled: Bool?, inviteNote: String?, emailConfirmedAt: ATProtocolDate?, deactivatedAt: ATProtocolDate?
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
                handle = try container.decode(String.self, forKey: .handle)

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
                try container.encode(value, forKey: .labels)
            }

            if let value = invitedBy {
                try container.encode(value, forKey: .invitedBy)
            }

            if let value = invites {
                try container.encode(value, forKey: .invites)
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

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
        }
    }

    public struct RepoViewNotFound: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#repoViewNotFound"
        public let did: String

        // Standard initializer
        public init(
            did: String
        ) {
            self.did = did
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }

    public struct RecordView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#recordView"
        public let uri: ATProtocolURI
        public let cid: String
        public let value: ATProtocolValueContainer
        public let blobCids: [String]
        public let indexedAt: ATProtocolDate
        public let moderation: Moderation
        public let repo: RepoView

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: String, value: ATProtocolValueContainer, blobCids: [String], indexedAt: ATProtocolDate, moderation: Moderation, repo: RepoView
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
                cid = try container.decode(String.self, forKey: .cid)

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
                blobCids = try container.decode([String].self, forKey: .blobCids)

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
        public let cid: String
        public let value: ATProtocolValueContainer
        public let blobs: [BlobView]
        public let labels: [ComAtprotoLabelDefs.Label]?
        public let indexedAt: ATProtocolDate
        public let moderation: ModerationDetail
        public let repo: RepoView

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: String, value: ATProtocolValueContainer, blobs: [BlobView], labels: [ComAtprotoLabelDefs.Label]?, indexedAt: ATProtocolDate, moderation: ModerationDetail, repo: RepoView
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
                cid = try container.decode(String.self, forKey: .cid)

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
                try container.encode(value, forKey: .labels)
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case subjectStatus
        }
    }

    public struct BlobView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.moderation.defs#blobView"
        public let cid: String
        public let mimeType: String
        public let size: Int
        public let createdAt: ATProtocolDate
        public let details: BlobViewDetailsUnion?
        public let moderation: Moderation?

        // Standard initializer
        public init(
            cid: String, mimeType: String, size: Int, createdAt: ATProtocolDate, details: BlobViewDetailsUnion?, moderation: Moderation?
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
                cid = try container.decode(String.self, forKey: .cid)

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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case width
            case height
            case length
        }
    }

    public enum ModEventViewEventUnion: Codable, ATProtocolCodable, ATProtocolValue {
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
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)
            LogManager.logDebug("ModEventViewEventUnion decoding: \(typeValue)")

            switch typeValue {
            case "tools.ozone.moderation.defs#modEventTakedown":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventTakedown")
                let value = try ToolsOzoneModerationDefs.ModEventTakedown(from: decoder)
                self = .toolsOzoneModerationDefsModEventTakedown(value)
            case "tools.ozone.moderation.defs#modEventReverseTakedown":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventReverseTakedown")
                let value = try ToolsOzoneModerationDefs.ModEventReverseTakedown(from: decoder)
                self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
            case "tools.ozone.moderation.defs#modEventComment":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventComment")
                let value = try ToolsOzoneModerationDefs.ModEventComment(from: decoder)
                self = .toolsOzoneModerationDefsModEventComment(value)
            case "tools.ozone.moderation.defs#modEventReport":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventReport")
                let value = try ToolsOzoneModerationDefs.ModEventReport(from: decoder)
                self = .toolsOzoneModerationDefsModEventReport(value)
            case "tools.ozone.moderation.defs#modEventLabel":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventLabel")
                let value = try ToolsOzoneModerationDefs.ModEventLabel(from: decoder)
                self = .toolsOzoneModerationDefsModEventLabel(value)
            case "tools.ozone.moderation.defs#modEventAcknowledge":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventAcknowledge")
                let value = try ToolsOzoneModerationDefs.ModEventAcknowledge(from: decoder)
                self = .toolsOzoneModerationDefsModEventAcknowledge(value)
            case "tools.ozone.moderation.defs#modEventEscalate":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventEscalate")
                let value = try ToolsOzoneModerationDefs.ModEventEscalate(from: decoder)
                self = .toolsOzoneModerationDefsModEventEscalate(value)
            case "tools.ozone.moderation.defs#modEventMute":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventMute")
                let value = try ToolsOzoneModerationDefs.ModEventMute(from: decoder)
                self = .toolsOzoneModerationDefsModEventMute(value)
            case "tools.ozone.moderation.defs#modEventUnmute":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventUnmute")
                let value = try ToolsOzoneModerationDefs.ModEventUnmute(from: decoder)
                self = .toolsOzoneModerationDefsModEventUnmute(value)
            case "tools.ozone.moderation.defs#modEventMuteReporter":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventMuteReporter")
                let value = try ToolsOzoneModerationDefs.ModEventMuteReporter(from: decoder)
                self = .toolsOzoneModerationDefsModEventMuteReporter(value)
            case "tools.ozone.moderation.defs#modEventUnmuteReporter":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventUnmuteReporter")
                let value = try ToolsOzoneModerationDefs.ModEventUnmuteReporter(from: decoder)
                self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
            case "tools.ozone.moderation.defs#modEventEmail":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventEmail")
                let value = try ToolsOzoneModerationDefs.ModEventEmail(from: decoder)
                self = .toolsOzoneModerationDefsModEventEmail(value)
            case "tools.ozone.moderation.defs#modEventResolveAppeal":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventResolveAppeal")
                let value = try ToolsOzoneModerationDefs.ModEventResolveAppeal(from: decoder)
                self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
            case "tools.ozone.moderation.defs#modEventDivert":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventDivert")
                let value = try ToolsOzoneModerationDefs.ModEventDivert(from: decoder)
                self = .toolsOzoneModerationDefsModEventDivert(value)
            case "tools.ozone.moderation.defs#modEventTag":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventTag")
                let value = try ToolsOzoneModerationDefs.ModEventTag(from: decoder)
                self = .toolsOzoneModerationDefsModEventTag(value)
            default:
                LogManager.logDebug("ModEventViewEventUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventTakedown")
                try container.encode("tools.ozone.moderation.defs#modEventTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventReverseTakedown")
                try container.encode("tools.ozone.moderation.defs#modEventReverseTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventComment(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventComment")
                try container.encode("tools.ozone.moderation.defs#modEventComment", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReport(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventReport")
                try container.encode("tools.ozone.moderation.defs#modEventReport", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventLabel(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventLabel")
                try container.encode("tools.ozone.moderation.defs#modEventLabel", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventAcknowledge")
                try container.encode("tools.ozone.moderation.defs#modEventAcknowledge", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventEscalate")
                try container.encode("tools.ozone.moderation.defs#modEventEscalate", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMute(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventMute")
                try container.encode("tools.ozone.moderation.defs#modEventMute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventUnmute")
                try container.encode("tools.ozone.moderation.defs#modEventUnmute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventMuteReporter")
                try container.encode("tools.ozone.moderation.defs#modEventMuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventUnmuteReporter")
                try container.encode("tools.ozone.moderation.defs#modEventUnmuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEmail(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventEmail")
                try container.encode("tools.ozone.moderation.defs#modEventEmail", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventResolveAppeal")
                try container.encode("tools.ozone.moderation.defs#modEventResolveAppeal", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventDivert(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventDivert")
                try container.encode("tools.ozone.moderation.defs#modEventDivert", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventTag(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventTag")
                try container.encode("tools.ozone.moderation.defs#modEventTag", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("ModEventViewEventUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? ModEventViewEventUnion else { return false }

            switch (self, otherValue) {
            case let (.toolsOzoneModerationDefsModEventTakedown(selfValue),
                      .toolsOzoneModerationDefsModEventTakedown(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventReverseTakedown(selfValue),
                      .toolsOzoneModerationDefsModEventReverseTakedown(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventComment(selfValue),
                      .toolsOzoneModerationDefsModEventComment(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventReport(selfValue),
                      .toolsOzoneModerationDefsModEventReport(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventLabel(selfValue),
                      .toolsOzoneModerationDefsModEventLabel(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventAcknowledge(selfValue),
                      .toolsOzoneModerationDefsModEventAcknowledge(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventEscalate(selfValue),
                      .toolsOzoneModerationDefsModEventEscalate(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventMute(selfValue),
                      .toolsOzoneModerationDefsModEventMute(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventUnmute(selfValue),
                      .toolsOzoneModerationDefsModEventUnmute(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventMuteReporter(selfValue),
                      .toolsOzoneModerationDefsModEventMuteReporter(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventUnmuteReporter(selfValue),
                      .toolsOzoneModerationDefsModEventUnmuteReporter(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventEmail(selfValue),
                      .toolsOzoneModerationDefsModEventEmail(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventResolveAppeal(selfValue),
                      .toolsOzoneModerationDefsModEventResolveAppeal(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventDivert(selfValue),
                      .toolsOzoneModerationDefsModEventDivert(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventTag(selfValue),
                      .toolsOzoneModerationDefsModEventTag(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }

    public enum ModEventViewSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case chatBskyConvoDefsMessageRef(ChatBskyConvoDefs.MessageRef)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)
            LogManager.logDebug("ModEventViewSubjectUnion decoding: \(typeValue)")

            switch typeValue {
            case "com.atproto.admin.defs#repoRef":
                LogManager.logDebug("Decoding as com.atproto.admin.defs#repoRef")
                let value = try ComAtprotoAdminDefs.RepoRef(from: decoder)
                self = .comAtprotoAdminDefsRepoRef(value)
            case "com.atproto.repo.strongRef":
                LogManager.logDebug("Decoding as com.atproto.repo.strongRef")
                let value = try ComAtprotoRepoStrongRef(from: decoder)
                self = .comAtprotoRepoStrongRef(value)
            case "chat.bsky.convo.defs#messageRef":
                LogManager.logDebug("Decoding as chat.bsky.convo.defs#messageRef")
                let value = try ChatBskyConvoDefs.MessageRef(from: decoder)
                self = .chatBskyConvoDefsMessageRef(value)
            default:
                LogManager.logDebug("ModEventViewSubjectUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                LogManager.logDebug("Encoding com.atproto.admin.defs#repoRef")
                try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoStrongRef(value):
                LogManager.logDebug("Encoding com.atproto.repo.strongRef")
                try container.encode("com.atproto.repo.strongRef", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsMessageRef(value):
                LogManager.logDebug("Encoding chat.bsky.convo.defs#messageRef")
                try container.encode("chat.bsky.convo.defs#messageRef", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("ModEventViewSubjectUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? ModEventViewSubjectUnion else { return false }

            switch (self, otherValue) {
            case let (.comAtprotoAdminDefsRepoRef(selfValue),
                      .comAtprotoAdminDefsRepoRef(otherValue)):
                return selfValue == otherValue
            case let (.comAtprotoRepoStrongRef(selfValue),
                      .comAtprotoRepoStrongRef(otherValue)):
                return selfValue == otherValue
            case let (.chatBskyConvoDefsMessageRef(selfValue),
                      .chatBskyConvoDefsMessageRef(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }

    public enum ModEventViewDetailEventUnion: Codable, ATProtocolCodable, ATProtocolValue {
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
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)
            LogManager.logDebug("ModEventViewDetailEventUnion decoding: \(typeValue)")

            switch typeValue {
            case "tools.ozone.moderation.defs#modEventTakedown":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventTakedown")
                let value = try ToolsOzoneModerationDefs.ModEventTakedown(from: decoder)
                self = .toolsOzoneModerationDefsModEventTakedown(value)
            case "tools.ozone.moderation.defs#modEventReverseTakedown":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventReverseTakedown")
                let value = try ToolsOzoneModerationDefs.ModEventReverseTakedown(from: decoder)
                self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
            case "tools.ozone.moderation.defs#modEventComment":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventComment")
                let value = try ToolsOzoneModerationDefs.ModEventComment(from: decoder)
                self = .toolsOzoneModerationDefsModEventComment(value)
            case "tools.ozone.moderation.defs#modEventReport":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventReport")
                let value = try ToolsOzoneModerationDefs.ModEventReport(from: decoder)
                self = .toolsOzoneModerationDefsModEventReport(value)
            case "tools.ozone.moderation.defs#modEventLabel":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventLabel")
                let value = try ToolsOzoneModerationDefs.ModEventLabel(from: decoder)
                self = .toolsOzoneModerationDefsModEventLabel(value)
            case "tools.ozone.moderation.defs#modEventAcknowledge":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventAcknowledge")
                let value = try ToolsOzoneModerationDefs.ModEventAcknowledge(from: decoder)
                self = .toolsOzoneModerationDefsModEventAcknowledge(value)
            case "tools.ozone.moderation.defs#modEventEscalate":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventEscalate")
                let value = try ToolsOzoneModerationDefs.ModEventEscalate(from: decoder)
                self = .toolsOzoneModerationDefsModEventEscalate(value)
            case "tools.ozone.moderation.defs#modEventMute":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventMute")
                let value = try ToolsOzoneModerationDefs.ModEventMute(from: decoder)
                self = .toolsOzoneModerationDefsModEventMute(value)
            case "tools.ozone.moderation.defs#modEventUnmute":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventUnmute")
                let value = try ToolsOzoneModerationDefs.ModEventUnmute(from: decoder)
                self = .toolsOzoneModerationDefsModEventUnmute(value)
            case "tools.ozone.moderation.defs#modEventMuteReporter":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventMuteReporter")
                let value = try ToolsOzoneModerationDefs.ModEventMuteReporter(from: decoder)
                self = .toolsOzoneModerationDefsModEventMuteReporter(value)
            case "tools.ozone.moderation.defs#modEventUnmuteReporter":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventUnmuteReporter")
                let value = try ToolsOzoneModerationDefs.ModEventUnmuteReporter(from: decoder)
                self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
            case "tools.ozone.moderation.defs#modEventEmail":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventEmail")
                let value = try ToolsOzoneModerationDefs.ModEventEmail(from: decoder)
                self = .toolsOzoneModerationDefsModEventEmail(value)
            case "tools.ozone.moderation.defs#modEventResolveAppeal":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventResolveAppeal")
                let value = try ToolsOzoneModerationDefs.ModEventResolveAppeal(from: decoder)
                self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
            case "tools.ozone.moderation.defs#modEventDivert":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventDivert")
                let value = try ToolsOzoneModerationDefs.ModEventDivert(from: decoder)
                self = .toolsOzoneModerationDefsModEventDivert(value)
            case "tools.ozone.moderation.defs#modEventTag":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#modEventTag")
                let value = try ToolsOzoneModerationDefs.ModEventTag(from: decoder)
                self = .toolsOzoneModerationDefsModEventTag(value)
            default:
                LogManager.logDebug("ModEventViewDetailEventUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventTakedown")
                try container.encode("tools.ozone.moderation.defs#modEventTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventReverseTakedown")
                try container.encode("tools.ozone.moderation.defs#modEventReverseTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventComment(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventComment")
                try container.encode("tools.ozone.moderation.defs#modEventComment", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReport(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventReport")
                try container.encode("tools.ozone.moderation.defs#modEventReport", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventLabel(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventLabel")
                try container.encode("tools.ozone.moderation.defs#modEventLabel", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventAcknowledge")
                try container.encode("tools.ozone.moderation.defs#modEventAcknowledge", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventEscalate")
                try container.encode("tools.ozone.moderation.defs#modEventEscalate", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMute(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventMute")
                try container.encode("tools.ozone.moderation.defs#modEventMute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventUnmute")
                try container.encode("tools.ozone.moderation.defs#modEventUnmute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventMuteReporter")
                try container.encode("tools.ozone.moderation.defs#modEventMuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventUnmuteReporter")
                try container.encode("tools.ozone.moderation.defs#modEventUnmuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEmail(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventEmail")
                try container.encode("tools.ozone.moderation.defs#modEventEmail", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventResolveAppeal")
                try container.encode("tools.ozone.moderation.defs#modEventResolveAppeal", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventDivert(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventDivert")
                try container.encode("tools.ozone.moderation.defs#modEventDivert", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventTag(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#modEventTag")
                try container.encode("tools.ozone.moderation.defs#modEventTag", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("ModEventViewDetailEventUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? ModEventViewDetailEventUnion else { return false }

            switch (self, otherValue) {
            case let (.toolsOzoneModerationDefsModEventTakedown(selfValue),
                      .toolsOzoneModerationDefsModEventTakedown(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventReverseTakedown(selfValue),
                      .toolsOzoneModerationDefsModEventReverseTakedown(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventComment(selfValue),
                      .toolsOzoneModerationDefsModEventComment(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventReport(selfValue),
                      .toolsOzoneModerationDefsModEventReport(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventLabel(selfValue),
                      .toolsOzoneModerationDefsModEventLabel(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventAcknowledge(selfValue),
                      .toolsOzoneModerationDefsModEventAcknowledge(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventEscalate(selfValue),
                      .toolsOzoneModerationDefsModEventEscalate(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventMute(selfValue),
                      .toolsOzoneModerationDefsModEventMute(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventUnmute(selfValue),
                      .toolsOzoneModerationDefsModEventUnmute(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventMuteReporter(selfValue),
                      .toolsOzoneModerationDefsModEventMuteReporter(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventUnmuteReporter(selfValue),
                      .toolsOzoneModerationDefsModEventUnmuteReporter(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventEmail(selfValue),
                      .toolsOzoneModerationDefsModEventEmail(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventResolveAppeal(selfValue),
                      .toolsOzoneModerationDefsModEventResolveAppeal(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventDivert(selfValue),
                      .toolsOzoneModerationDefsModEventDivert(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsModEventTag(selfValue),
                      .toolsOzoneModerationDefsModEventTag(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }

    public enum ModEventViewDetailSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case toolsOzoneModerationDefsRepoView(ToolsOzoneModerationDefs.RepoView)
        case toolsOzoneModerationDefsRepoViewNotFound(ToolsOzoneModerationDefs.RepoViewNotFound)
        case toolsOzoneModerationDefsRecordView(ToolsOzoneModerationDefs.RecordView)
        case toolsOzoneModerationDefsRecordViewNotFound(ToolsOzoneModerationDefs.RecordViewNotFound)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)
            LogManager.logDebug("ModEventViewDetailSubjectUnion decoding: \(typeValue)")

            switch typeValue {
            case "tools.ozone.moderation.defs#repoView":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#repoView")
                let value = try ToolsOzoneModerationDefs.RepoView(from: decoder)
                self = .toolsOzoneModerationDefsRepoView(value)
            case "tools.ozone.moderation.defs#repoViewNotFound":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#repoViewNotFound")
                let value = try ToolsOzoneModerationDefs.RepoViewNotFound(from: decoder)
                self = .toolsOzoneModerationDefsRepoViewNotFound(value)
            case "tools.ozone.moderation.defs#recordView":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#recordView")
                let value = try ToolsOzoneModerationDefs.RecordView(from: decoder)
                self = .toolsOzoneModerationDefsRecordView(value)
            case "tools.ozone.moderation.defs#recordViewNotFound":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#recordViewNotFound")
                let value = try ToolsOzoneModerationDefs.RecordViewNotFound(from: decoder)
                self = .toolsOzoneModerationDefsRecordViewNotFound(value)
            default:
                LogManager.logDebug("ModEventViewDetailSubjectUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsRepoView(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#repoView")
                try container.encode("tools.ozone.moderation.defs#repoView", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#repoViewNotFound")
                try container.encode("tools.ozone.moderation.defs#repoViewNotFound", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRecordView(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#recordView")
                try container.encode("tools.ozone.moderation.defs#recordView", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRecordViewNotFound(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#recordViewNotFound")
                try container.encode("tools.ozone.moderation.defs#recordViewNotFound", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("ModEventViewDetailSubjectUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? ModEventViewDetailSubjectUnion else { return false }

            switch (self, otherValue) {
            case let (.toolsOzoneModerationDefsRepoView(selfValue),
                      .toolsOzoneModerationDefsRepoView(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsRepoViewNotFound(selfValue),
                      .toolsOzoneModerationDefsRepoViewNotFound(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsRecordView(selfValue),
                      .toolsOzoneModerationDefsRecordView(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsRecordViewNotFound(selfValue),
                      .toolsOzoneModerationDefsRecordViewNotFound(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }

    public enum SubjectStatusViewSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)
            LogManager.logDebug("SubjectStatusViewSubjectUnion decoding: \(typeValue)")

            switch typeValue {
            case "com.atproto.admin.defs#repoRef":
                LogManager.logDebug("Decoding as com.atproto.admin.defs#repoRef")
                let value = try ComAtprotoAdminDefs.RepoRef(from: decoder)
                self = .comAtprotoAdminDefsRepoRef(value)
            case "com.atproto.repo.strongRef":
                LogManager.logDebug("Decoding as com.atproto.repo.strongRef")
                let value = try ComAtprotoRepoStrongRef(from: decoder)
                self = .comAtprotoRepoStrongRef(value)
            default:
                LogManager.logDebug("SubjectStatusViewSubjectUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                LogManager.logDebug("Encoding com.atproto.admin.defs#repoRef")
                try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoStrongRef(value):
                LogManager.logDebug("Encoding com.atproto.repo.strongRef")
                try container.encode("com.atproto.repo.strongRef", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("SubjectStatusViewSubjectUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? SubjectStatusViewSubjectUnion else { return false }

            switch (self, otherValue) {
            case let (.comAtprotoAdminDefsRepoRef(selfValue),
                      .comAtprotoAdminDefsRepoRef(otherValue)):
                return selfValue == otherValue
            case let (.comAtprotoRepoStrongRef(selfValue),
                      .comAtprotoRepoStrongRef(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }

    public enum SubjectReviewState: String, Codable, ATProtocolCodable, ATProtocolValue, CaseIterable {
        //
        case reviewopen = "#reviewOpen"
        //
        case reviewescalated = "#reviewEscalated"
        //
        case reviewclosed = "#reviewClosed"
        //
        case reviewnone = "#reviewNone"

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherEnum = other as? SubjectReviewState else { return false }
            return rawValue == otherEnum.rawValue
        }
    }

    public enum BlobViewDetailsUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case toolsOzoneModerationDefsImageDetails(ToolsOzoneModerationDefs.ImageDetails)
        case toolsOzoneModerationDefsVideoDetails(ToolsOzoneModerationDefs.VideoDetails)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)
            LogManager.logDebug("BlobViewDetailsUnion decoding: \(typeValue)")

            switch typeValue {
            case "tools.ozone.moderation.defs#imageDetails":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#imageDetails")
                let value = try ToolsOzoneModerationDefs.ImageDetails(from: decoder)
                self = .toolsOzoneModerationDefsImageDetails(value)
            case "tools.ozone.moderation.defs#videoDetails":
                LogManager.logDebug("Decoding as tools.ozone.moderation.defs#videoDetails")
                let value = try ToolsOzoneModerationDefs.VideoDetails(from: decoder)
                self = .toolsOzoneModerationDefsVideoDetails(value)
            default:
                LogManager.logDebug("BlobViewDetailsUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsImageDetails(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#imageDetails")
                try container.encode("tools.ozone.moderation.defs#imageDetails", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsVideoDetails(value):
                LogManager.logDebug("Encoding tools.ozone.moderation.defs#videoDetails")
                try container.encode("tools.ozone.moderation.defs#videoDetails", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("BlobViewDetailsUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? BlobViewDetailsUnion else { return false }

            switch (self, otherValue) {
            case let (.toolsOzoneModerationDefsImageDetails(selfValue),
                      .toolsOzoneModerationDefsImageDetails(otherValue)):
                return selfValue == otherValue
            case let (.toolsOzoneModerationDefsVideoDetails(selfValue),
                      .toolsOzoneModerationDefsVideoDetails(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }
}
