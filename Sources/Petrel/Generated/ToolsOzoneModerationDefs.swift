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
        public let hosting: SubjectStatusViewHostingUnion?
        public let subjectBlobCids: [String]?
        public let subjectRepoHandle: String?
        public let updatedAt: ATProtocolDate
        public let createdAt: ATProtocolDate
        public let reviewState: SubjectReviewState
        public let comment: String?
        public let priorityScore: Int?
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
        public let accountStats: AccountStats?
        public let recordsStats: RecordsStats?

        // Standard initializer
        public init(
            id: Int, subject: SubjectStatusViewSubjectUnion, hosting: SubjectStatusViewHostingUnion?, subjectBlobCids: [String]?, subjectRepoHandle: String?, updatedAt: ATProtocolDate, createdAt: ATProtocolDate, reviewState: SubjectReviewState, comment: String?, priorityScore: Int?, muteUntil: ATProtocolDate?, muteReportingUntil: ATProtocolDate?, lastReviewedBy: String?, lastReviewedAt: ATProtocolDate?, lastReportedAt: ATProtocolDate?, lastAppealedAt: ATProtocolDate?, takendown: Bool?, appealed: Bool?, suspendUntil: ATProtocolDate?, tags: [String]?, accountStats: AccountStats?, recordsStats: RecordsStats?
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
                try container.encode(value, forKey: .tags)
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
                try container.encode(value, forKey: .policies)
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
        public let handle: String?
        public let pdsHost: URI?
        public let tombstone: Bool?
        public let timestamp: ATProtocolDate

        // Standard initializer
        public init(
            comment: String?, handle: String?, pdsHost: URI?, tombstone: Bool?, timestamp: ATProtocolDate
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
                handle = try container.decodeIfPresent(String.self, forKey: .handle)

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
        public let cid: String?
        public let timestamp: ATProtocolDate

        // Standard initializer
        public init(
            comment: String?, op: String, cid: String?, timestamp: ATProtocolDate
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
                cid = try container.decodeIfPresent(String.self, forKey: .cid)

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
        public let threatSignatures: [ComAtprotoAdminDefs.ThreatSignature]?

        // Standard initializer
        public init(
            did: String, handle: String, email: String?, relatedRecords: [ATProtocolValueContainer], indexedAt: ATProtocolDate, moderation: Moderation, invitedBy: ComAtprotoServerDefs.InviteCode?, invitesDisabled: Bool?, inviteNote: String?, deactivatedAt: ATProtocolDate?, threatSignatures: [ComAtprotoAdminDefs.ThreatSignature]?
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
                try container.encode(value, forKey: .threatSignatures)
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
        public let threatSignatures: [ComAtprotoAdminDefs.ThreatSignature]?

        // Standard initializer
        public init(
            did: String, handle: String, email: String?, relatedRecords: [ATProtocolValueContainer], indexedAt: ATProtocolDate, moderation: ModerationDetail, labels: [ComAtprotoLabelDefs.Label]?, invitedBy: ComAtprotoServerDefs.InviteCode?, invites: [ComAtprotoServerDefs.InviteCode]?, invitesDisabled: Bool?, inviteNote: String?, emailConfirmedAt: ATProtocolDate?, deactivatedAt: ATProtocolDate?, threatSignatures: [ComAtprotoAdminDefs.ThreatSignature]?
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

            if let value = threatSignatures {
                try container.encode(value, forKey: .threatSignatures)
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
        public let did: String
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
            did: String, accountReportCount: Int, recordReportCount: Int, reportedAccountCount: Int, reportedRecordCount: Int, takendownAccountCount: Int, takendownRecordCount: Int, labeledAccountCount: Int, labeledRecordCount: Int
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
                did = try container.decode(String.self, forKey: .did)

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

    public enum ModEventViewEventUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
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

        public static func toolsOzoneModerationDefsModEventTakedown(_ value: ToolsOzoneModerationDefs.ModEventTakedown) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventTakedown(value)
        }

        public static func toolsOzoneModerationDefsModEventReverseTakedown(_ value: ToolsOzoneModerationDefs.ModEventReverseTakedown) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventReverseTakedown(value)
        }

        public static func toolsOzoneModerationDefsModEventComment(_ value: ToolsOzoneModerationDefs.ModEventComment) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventComment(value)
        }

        public static func toolsOzoneModerationDefsModEventReport(_ value: ToolsOzoneModerationDefs.ModEventReport) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventReport(value)
        }

        public static func toolsOzoneModerationDefsModEventLabel(_ value: ToolsOzoneModerationDefs.ModEventLabel) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventLabel(value)
        }

        public static func toolsOzoneModerationDefsModEventAcknowledge(_ value: ToolsOzoneModerationDefs.ModEventAcknowledge) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventAcknowledge(value)
        }

        public static func toolsOzoneModerationDefsModEventEscalate(_ value: ToolsOzoneModerationDefs.ModEventEscalate) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventEscalate(value)
        }

        public static func toolsOzoneModerationDefsModEventMute(_ value: ToolsOzoneModerationDefs.ModEventMute) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventMute(value)
        }

        public static func toolsOzoneModerationDefsModEventUnmute(_ value: ToolsOzoneModerationDefs.ModEventUnmute) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventUnmute(value)
        }

        public static func toolsOzoneModerationDefsModEventMuteReporter(_ value: ToolsOzoneModerationDefs.ModEventMuteReporter) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventMuteReporter(value)
        }

        public static func toolsOzoneModerationDefsModEventUnmuteReporter(_ value: ToolsOzoneModerationDefs.ModEventUnmuteReporter) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventUnmuteReporter(value)
        }

        public static func toolsOzoneModerationDefsModEventEmail(_ value: ToolsOzoneModerationDefs.ModEventEmail) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventEmail(value)
        }

        public static func toolsOzoneModerationDefsModEventResolveAppeal(_ value: ToolsOzoneModerationDefs.ModEventResolveAppeal) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventResolveAppeal(value)
        }

        public static func toolsOzoneModerationDefsModEventDivert(_ value: ToolsOzoneModerationDefs.ModEventDivert) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventDivert(value)
        }

        public static func toolsOzoneModerationDefsModEventTag(_ value: ToolsOzoneModerationDefs.ModEventTag) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventTag(value)
        }

        public static func toolsOzoneModerationDefsAccountEvent(_ value: ToolsOzoneModerationDefs.AccountEvent) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsAccountEvent(value)
        }

        public static func toolsOzoneModerationDefsIdentityEvent(_ value: ToolsOzoneModerationDefs.IdentityEvent) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsIdentityEvent(value)
        }

        public static func toolsOzoneModerationDefsRecordEvent(_ value: ToolsOzoneModerationDefs.RecordEvent) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsRecordEvent(value)
        }

        public static func toolsOzoneModerationDefsModEventPriorityScore(_ value: ToolsOzoneModerationDefs.ModEventPriorityScore) -> ModEventViewEventUnion {
            return .toolsOzoneModerationDefsModEventPriorityScore(value)
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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventComment(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventReport(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventLabel(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventMute(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventEmail(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventDivert(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventTag(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsAccountEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsRecordEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsModEventTakedown(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventTakedown {
                            self = .toolsOzoneModerationDefsModEventTakedown(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventReverseTakedown {
                            self = .toolsOzoneModerationDefsModEventReverseTakedown(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventComment(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventComment {
                            self = .toolsOzoneModerationDefsModEventComment(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventReport(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventReport {
                            self = .toolsOzoneModerationDefsModEventReport(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventLabel(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventLabel {
                            self = .toolsOzoneModerationDefsModEventLabel(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventAcknowledge {
                            self = .toolsOzoneModerationDefsModEventAcknowledge(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventEscalate(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventEscalate {
                            self = .toolsOzoneModerationDefsModEventEscalate(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventMute(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventMute {
                            self = .toolsOzoneModerationDefsModEventMute(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventUnmute(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventUnmute {
                            self = .toolsOzoneModerationDefsModEventUnmute(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventMuteReporter {
                            self = .toolsOzoneModerationDefsModEventMuteReporter(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventUnmuteReporter {
                            self = .toolsOzoneModerationDefsModEventUnmuteReporter(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventEmail(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventEmail {
                            self = .toolsOzoneModerationDefsModEventEmail(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventResolveAppeal {
                            self = .toolsOzoneModerationDefsModEventResolveAppeal(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventDivert(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventDivert {
                            self = .toolsOzoneModerationDefsModEventDivert(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventTag(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventTag {
                            self = .toolsOzoneModerationDefsModEventTag(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsAccountEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.AccountEvent {
                            self = .toolsOzoneModerationDefsAccountEvent(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsIdentityEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.IdentityEvent {
                            self = .toolsOzoneModerationDefsIdentityEvent(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsRecordEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.RecordEvent {
                            self = .toolsOzoneModerationDefsRecordEvent(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventPriorityScore {
                            self = .toolsOzoneModerationDefsModEventPriorityScore(updatedValue)
                        }
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ModEventViewSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case chatBskyConvoDefsMessageRef(ChatBskyConvoDefs.MessageRef)
        case unexpected(ATProtocolValueContainer)

        public static func comAtprotoAdminDefsRepoRef(_ value: ComAtprotoAdminDefs.RepoRef) -> ModEventViewSubjectUnion {
            return .comAtprotoAdminDefsRepoRef(value)
        }

        public static func comAtprotoRepoStrongRef(_ value: ComAtprotoRepoStrongRef) -> ModEventViewSubjectUnion {
            return .comAtprotoRepoStrongRef(value)
        }

        public static func chatBskyConvoDefsMessageRef(_ value: ChatBskyConvoDefs.MessageRef) -> ModEventViewSubjectUnion {
            return .chatBskyConvoDefsMessageRef(value)
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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoRepoStrongRef(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .chatBskyConvoDefsMessageRef(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .comAtprotoAdminDefsRepoRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ComAtprotoAdminDefs.RepoRef {
                            self = .comAtprotoAdminDefsRepoRef(updatedValue)
                        }
                    }
                }
            case var .comAtprotoRepoStrongRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ComAtprotoRepoStrongRef {
                            self = .comAtprotoRepoStrongRef(updatedValue)
                        }
                    }
                }
            case var .chatBskyConvoDefsMessageRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ChatBskyConvoDefs.MessageRef {
                            self = .chatBskyConvoDefsMessageRef(updatedValue)
                        }
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ModEventViewDetailEventUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
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

        public static func toolsOzoneModerationDefsModEventTakedown(_ value: ToolsOzoneModerationDefs.ModEventTakedown) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventTakedown(value)
        }

        public static func toolsOzoneModerationDefsModEventReverseTakedown(_ value: ToolsOzoneModerationDefs.ModEventReverseTakedown) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventReverseTakedown(value)
        }

        public static func toolsOzoneModerationDefsModEventComment(_ value: ToolsOzoneModerationDefs.ModEventComment) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventComment(value)
        }

        public static func toolsOzoneModerationDefsModEventReport(_ value: ToolsOzoneModerationDefs.ModEventReport) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventReport(value)
        }

        public static func toolsOzoneModerationDefsModEventLabel(_ value: ToolsOzoneModerationDefs.ModEventLabel) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventLabel(value)
        }

        public static func toolsOzoneModerationDefsModEventAcknowledge(_ value: ToolsOzoneModerationDefs.ModEventAcknowledge) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventAcknowledge(value)
        }

        public static func toolsOzoneModerationDefsModEventEscalate(_ value: ToolsOzoneModerationDefs.ModEventEscalate) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventEscalate(value)
        }

        public static func toolsOzoneModerationDefsModEventMute(_ value: ToolsOzoneModerationDefs.ModEventMute) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventMute(value)
        }

        public static func toolsOzoneModerationDefsModEventUnmute(_ value: ToolsOzoneModerationDefs.ModEventUnmute) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventUnmute(value)
        }

        public static func toolsOzoneModerationDefsModEventMuteReporter(_ value: ToolsOzoneModerationDefs.ModEventMuteReporter) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventMuteReporter(value)
        }

        public static func toolsOzoneModerationDefsModEventUnmuteReporter(_ value: ToolsOzoneModerationDefs.ModEventUnmuteReporter) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventUnmuteReporter(value)
        }

        public static func toolsOzoneModerationDefsModEventEmail(_ value: ToolsOzoneModerationDefs.ModEventEmail) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventEmail(value)
        }

        public static func toolsOzoneModerationDefsModEventResolveAppeal(_ value: ToolsOzoneModerationDefs.ModEventResolveAppeal) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventResolveAppeal(value)
        }

        public static func toolsOzoneModerationDefsModEventDivert(_ value: ToolsOzoneModerationDefs.ModEventDivert) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventDivert(value)
        }

        public static func toolsOzoneModerationDefsModEventTag(_ value: ToolsOzoneModerationDefs.ModEventTag) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventTag(value)
        }

        public static func toolsOzoneModerationDefsAccountEvent(_ value: ToolsOzoneModerationDefs.AccountEvent) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsAccountEvent(value)
        }

        public static func toolsOzoneModerationDefsIdentityEvent(_ value: ToolsOzoneModerationDefs.IdentityEvent) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsIdentityEvent(value)
        }

        public static func toolsOzoneModerationDefsRecordEvent(_ value: ToolsOzoneModerationDefs.RecordEvent) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsRecordEvent(value)
        }

        public static func toolsOzoneModerationDefsModEventPriorityScore(_ value: ToolsOzoneModerationDefs.ModEventPriorityScore) -> ModEventViewDetailEventUnion {
            return .toolsOzoneModerationDefsModEventPriorityScore(value)
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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventComment(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventReport(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventLabel(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventMute(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventEmail(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventDivert(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventTag(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsAccountEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsRecordEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsModEventTakedown(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventTakedown {
                            self = .toolsOzoneModerationDefsModEventTakedown(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventReverseTakedown {
                            self = .toolsOzoneModerationDefsModEventReverseTakedown(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventComment(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventComment {
                            self = .toolsOzoneModerationDefsModEventComment(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventReport(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventReport {
                            self = .toolsOzoneModerationDefsModEventReport(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventLabel(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventLabel {
                            self = .toolsOzoneModerationDefsModEventLabel(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventAcknowledge {
                            self = .toolsOzoneModerationDefsModEventAcknowledge(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventEscalate(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventEscalate {
                            self = .toolsOzoneModerationDefsModEventEscalate(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventMute(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventMute {
                            self = .toolsOzoneModerationDefsModEventMute(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventUnmute(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventUnmute {
                            self = .toolsOzoneModerationDefsModEventUnmute(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventMuteReporter {
                            self = .toolsOzoneModerationDefsModEventMuteReporter(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventUnmuteReporter {
                            self = .toolsOzoneModerationDefsModEventUnmuteReporter(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventEmail(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventEmail {
                            self = .toolsOzoneModerationDefsModEventEmail(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventResolveAppeal {
                            self = .toolsOzoneModerationDefsModEventResolveAppeal(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventDivert(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventDivert {
                            self = .toolsOzoneModerationDefsModEventDivert(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventTag(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventTag {
                            self = .toolsOzoneModerationDefsModEventTag(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsAccountEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.AccountEvent {
                            self = .toolsOzoneModerationDefsAccountEvent(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsIdentityEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.IdentityEvent {
                            self = .toolsOzoneModerationDefsIdentityEvent(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsRecordEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.RecordEvent {
                            self = .toolsOzoneModerationDefsRecordEvent(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ModEventPriorityScore {
                            self = .toolsOzoneModerationDefsModEventPriorityScore(updatedValue)
                        }
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ModEventViewDetailSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case toolsOzoneModerationDefsRepoView(ToolsOzoneModerationDefs.RepoView)
        case toolsOzoneModerationDefsRepoViewNotFound(ToolsOzoneModerationDefs.RepoViewNotFound)
        case toolsOzoneModerationDefsRecordView(ToolsOzoneModerationDefs.RecordView)
        case toolsOzoneModerationDefsRecordViewNotFound(ToolsOzoneModerationDefs.RecordViewNotFound)
        case unexpected(ATProtocolValueContainer)

        public static func toolsOzoneModerationDefsRepoView(_ value: ToolsOzoneModerationDefs.RepoView) -> ModEventViewDetailSubjectUnion {
            return .toolsOzoneModerationDefsRepoView(value)
        }

        public static func toolsOzoneModerationDefsRepoViewNotFound(_ value: ToolsOzoneModerationDefs.RepoViewNotFound) -> ModEventViewDetailSubjectUnion {
            return .toolsOzoneModerationDefsRepoViewNotFound(value)
        }

        public static func toolsOzoneModerationDefsRecordView(_ value: ToolsOzoneModerationDefs.RecordView) -> ModEventViewDetailSubjectUnion {
            return .toolsOzoneModerationDefsRecordView(value)
        }

        public static func toolsOzoneModerationDefsRecordViewNotFound(_ value: ToolsOzoneModerationDefs.RecordViewNotFound) -> ModEventViewDetailSubjectUnion {
            return .toolsOzoneModerationDefsRecordViewNotFound(value)
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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsRepoView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsRecordView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsRecordViewNotFound(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsRepoView(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.RepoView {
                            self = .toolsOzoneModerationDefsRepoView(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsRepoViewNotFound(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.RepoViewNotFound {
                            self = .toolsOzoneModerationDefsRepoViewNotFound(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsRecordView(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.RecordView {
                            self = .toolsOzoneModerationDefsRecordView(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsRecordViewNotFound(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.RecordViewNotFound {
                            self = .toolsOzoneModerationDefsRecordViewNotFound(updatedValue)
                        }
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum SubjectStatusViewSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case unexpected(ATProtocolValueContainer)

        public static func comAtprotoAdminDefsRepoRef(_ value: ComAtprotoAdminDefs.RepoRef) -> SubjectStatusViewSubjectUnion {
            return .comAtprotoAdminDefsRepoRef(value)
        }

        public static func comAtprotoRepoStrongRef(_ value: ComAtprotoRepoStrongRef) -> SubjectStatusViewSubjectUnion {
            return .comAtprotoRepoStrongRef(value)
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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoRepoStrongRef(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .comAtprotoAdminDefsRepoRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ComAtprotoAdminDefs.RepoRef {
                            self = .comAtprotoAdminDefsRepoRef(updatedValue)
                        }
                    }
                }
            case var .comAtprotoRepoStrongRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ComAtprotoRepoStrongRef {
                            self = .comAtprotoRepoStrongRef(updatedValue)
                        }
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum SubjectStatusViewHostingUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case toolsOzoneModerationDefsAccountHosting(ToolsOzoneModerationDefs.AccountHosting)
        case toolsOzoneModerationDefsRecordHosting(ToolsOzoneModerationDefs.RecordHosting)
        case unexpected(ATProtocolValueContainer)

        public static func toolsOzoneModerationDefsAccountHosting(_ value: ToolsOzoneModerationDefs.AccountHosting) -> SubjectStatusViewHostingUnion {
            return .toolsOzoneModerationDefsAccountHosting(value)
        }

        public static func toolsOzoneModerationDefsRecordHosting(_ value: ToolsOzoneModerationDefs.RecordHosting) -> SubjectStatusViewHostingUnion {
            return .toolsOzoneModerationDefsRecordHosting(value)
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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsAccountHosting(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsRecordHosting(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsAccountHosting(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.AccountHosting {
                            self = .toolsOzoneModerationDefsAccountHosting(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsRecordHosting(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.RecordHosting {
                            self = .toolsOzoneModerationDefsRecordHosting(updatedValue)
                        }
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
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

    public enum BlobViewDetailsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case toolsOzoneModerationDefsImageDetails(ToolsOzoneModerationDefs.ImageDetails)
        case toolsOzoneModerationDefsVideoDetails(ToolsOzoneModerationDefs.VideoDetails)
        case unexpected(ATProtocolValueContainer)

        public static func toolsOzoneModerationDefsImageDetails(_ value: ToolsOzoneModerationDefs.ImageDetails) -> BlobViewDetailsUnion {
            return .toolsOzoneModerationDefsImageDetails(value)
        }

        public static func toolsOzoneModerationDefsVideoDetails(_ value: ToolsOzoneModerationDefs.VideoDetails) -> BlobViewDetailsUnion {
            return .toolsOzoneModerationDefsVideoDetails(value)
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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsImageDetails(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsVideoDetails(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsImageDetails(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.ImageDetails {
                            self = .toolsOzoneModerationDefsImageDetails(updatedValue)
                        }
                    }
                }
            case var .toolsOzoneModerationDefsVideoDetails(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ToolsOzoneModerationDefs.VideoDetails {
                            self = .toolsOzoneModerationDefsVideoDetails(updatedValue)
                        }
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}
