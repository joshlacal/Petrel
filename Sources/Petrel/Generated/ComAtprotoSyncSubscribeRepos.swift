import Foundation

// lexicon: 1, id: com.atproto.sync.subscribeRepos

public enum ComAtprotoSyncSubscribeRepos {
    public static let typeIdentifier = "com.atproto.sync.subscribeRepos"

    public struct Commit: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.sync.subscribeRepos#commit"
        public let seq: Int
        public let rebase: Bool
        public let tooBig: Bool
        public let repo: DID
        public let commit: CID
        public let rev: TID
        public let since: TID
        public let blocks: Bytes
        public let ops: [RepoOp]
        public let blobs: [CID]
        public let prevData: CID?
        public let time: ATProtocolDate

        // Standard initializer
        public init(
            seq: Int, rebase: Bool, tooBig: Bool, repo: DID, commit: CID, rev: TID, since: TID, blocks: Bytes, ops: [RepoOp], blobs: [CID], prevData: CID?, time: ATProtocolDate
        ) {
            self.seq = seq
            self.rebase = rebase
            self.tooBig = tooBig
            self.repo = repo
            self.commit = commit
            self.rev = rev
            self.since = since
            self.blocks = blocks
            self.ops = ops
            self.blobs = blobs
            self.prevData = prevData
            self.time = time
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                seq = try container.decode(Int.self, forKey: .seq)

            } catch {
                LogManager.logError("Decoding error for required property 'seq': \(error)")

                throw error
            }
            do {
                rebase = try container.decode(Bool.self, forKey: .rebase)

            } catch {
                LogManager.logError("Decoding error for required property 'rebase': \(error)")

                throw error
            }
            do {
                tooBig = try container.decode(Bool.self, forKey: .tooBig)

            } catch {
                LogManager.logError("Decoding error for required property 'tooBig': \(error)")

                throw error
            }
            do {
                repo = try container.decode(DID.self, forKey: .repo)

            } catch {
                LogManager.logError("Decoding error for required property 'repo': \(error)")

                throw error
            }
            do {
                commit = try container.decode(CID.self, forKey: .commit)

            } catch {
                LogManager.logError("Decoding error for required property 'commit': \(error)")

                throw error
            }
            do {
                rev = try container.decode(TID.self, forKey: .rev)

            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")

                throw error
            }
            do {
                since = try container.decode(TID.self, forKey: .since)

            } catch {
                LogManager.logError("Decoding error for required property 'since': \(error)")

                throw error
            }
            do {
                blocks = try container.decode(Bytes.self, forKey: .blocks)

            } catch {
                LogManager.logError("Decoding error for required property 'blocks': \(error)")

                throw error
            }
            do {
                ops = try container.decode([RepoOp].self, forKey: .ops)

            } catch {
                LogManager.logError("Decoding error for required property 'ops': \(error)")

                throw error
            }
            do {
                blobs = try container.decode([CID].self, forKey: .blobs)

            } catch {
                LogManager.logError("Decoding error for required property 'blobs': \(error)")

                throw error
            }
            do {
                prevData = try container.decodeIfPresent(CID.self, forKey: .prevData)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'prevData': \(error)")

                throw error
            }
            do {
                time = try container.decode(ATProtocolDate.self, forKey: .time)

            } catch {
                LogManager.logError("Decoding error for required property 'time': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(seq, forKey: .seq)

            try container.encode(rebase, forKey: .rebase)

            try container.encode(tooBig, forKey: .tooBig)

            try container.encode(repo, forKey: .repo)

            try container.encode(commit, forKey: .commit)

            try container.encode(rev, forKey: .rev)

            try container.encode(since, forKey: .since)

            try container.encode(blocks, forKey: .blocks)

            try container.encode(ops, forKey: .ops)

            try container.encode(blobs, forKey: .blobs)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(prevData, forKey: .prevData)

            try container.encode(time, forKey: .time)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(seq)
            hasher.combine(rebase)
            hasher.combine(tooBig)
            hasher.combine(repo)
            hasher.combine(commit)
            hasher.combine(rev)
            hasher.combine(since)
            hasher.combine(blocks)
            hasher.combine(ops)
            hasher.combine(blobs)
            if let value = prevData {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(time)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if seq != other.seq {
                return false
            }

            if rebase != other.rebase {
                return false
            }

            if tooBig != other.tooBig {
                return false
            }

            if repo != other.repo {
                return false
            }

            if commit != other.commit {
                return false
            }

            if rev != other.rev {
                return false
            }

            if since != other.since {
                return false
            }

            if blocks != other.blocks {
                return false
            }

            if ops != other.ops {
                return false
            }

            if blobs != other.blobs {
                return false
            }

            if prevData != other.prevData {
                return false
            }

            if time != other.time {
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

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let seqValue = try seq.toCBORValue()
            map = map.adding(key: "seq", value: seqValue)

            let rebaseValue = try rebase.toCBORValue()
            map = map.adding(key: "rebase", value: rebaseValue)

            let tooBigValue = try tooBig.toCBORValue()
            map = map.adding(key: "tooBig", value: tooBigValue)

            let repoValue = try repo.toCBORValue()
            map = map.adding(key: "repo", value: repoValue)

            let commitValue = try commit.toCBORValue()
            map = map.adding(key: "commit", value: commitValue)

            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)

            let sinceValue = try since.toCBORValue()
            map = map.adding(key: "since", value: sinceValue)

            let blocksValue = try blocks.toCBORValue()
            map = map.adding(key: "blocks", value: blocksValue)

            let opsValue = try ops.toCBORValue()
            map = map.adding(key: "ops", value: opsValue)

            let blobsValue = try blobs.toCBORValue()
            map = map.adding(key: "blobs", value: blobsValue)

            if let value = prevData {
                // Encode optional property even if it's an empty array for CBOR

                let prevDataValue = try value.toCBORValue()
                map = map.adding(key: "prevData", value: prevDataValue)
            }

            let timeValue = try time.toCBORValue()
            map = map.adding(key: "time", value: timeValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case seq
            case rebase
            case tooBig
            case repo
            case commit
            case rev
            case since
            case blocks
            case ops
            case blobs
            case prevData
            case time
        }
    }

    public struct Sync: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.sync.subscribeRepos#sync"
        public let seq: Int
        public let did: DID
        public let blocks: Bytes
        public let rev: String
        public let time: ATProtocolDate

        // Standard initializer
        public init(
            seq: Int, did: DID, blocks: Bytes, rev: String, time: ATProtocolDate
        ) {
            self.seq = seq
            self.did = did
            self.blocks = blocks
            self.rev = rev
            self.time = time
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                seq = try container.decode(Int.self, forKey: .seq)

            } catch {
                LogManager.logError("Decoding error for required property 'seq': \(error)")

                throw error
            }
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")

                throw error
            }
            do {
                blocks = try container.decode(Bytes.self, forKey: .blocks)

            } catch {
                LogManager.logError("Decoding error for required property 'blocks': \(error)")

                throw error
            }
            do {
                rev = try container.decode(String.self, forKey: .rev)

            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")

                throw error
            }
            do {
                time = try container.decode(ATProtocolDate.self, forKey: .time)

            } catch {
                LogManager.logError("Decoding error for required property 'time': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(seq, forKey: .seq)

            try container.encode(did, forKey: .did)

            try container.encode(blocks, forKey: .blocks)

            try container.encode(rev, forKey: .rev)

            try container.encode(time, forKey: .time)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(seq)
            hasher.combine(did)
            hasher.combine(blocks)
            hasher.combine(rev)
            hasher.combine(time)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if seq != other.seq {
                return false
            }

            if did != other.did {
                return false
            }

            if blocks != other.blocks {
                return false
            }

            if rev != other.rev {
                return false
            }

            if time != other.time {
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

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let seqValue = try seq.toCBORValue()
            map = map.adding(key: "seq", value: seqValue)

            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)

            let blocksValue = try blocks.toCBORValue()
            map = map.adding(key: "blocks", value: blocksValue)

            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)

            let timeValue = try time.toCBORValue()
            map = map.adding(key: "time", value: timeValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case seq
            case did
            case blocks
            case rev
            case time
        }
    }

    public struct Identity: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.sync.subscribeRepos#identity"
        public let seq: Int
        public let did: DID
        public let time: ATProtocolDate
        public let handle: Handle?

        // Standard initializer
        public init(
            seq: Int, did: DID, time: ATProtocolDate, handle: Handle?
        ) {
            self.seq = seq
            self.did = did
            self.time = time
            self.handle = handle
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                seq = try container.decode(Int.self, forKey: .seq)

            } catch {
                LogManager.logError("Decoding error for required property 'seq': \(error)")

                throw error
            }
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")

                throw error
            }
            do {
                time = try container.decode(ATProtocolDate.self, forKey: .time)

            } catch {
                LogManager.logError("Decoding error for required property 'time': \(error)")

                throw error
            }
            do {
                handle = try container.decodeIfPresent(Handle.self, forKey: .handle)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'handle': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(seq, forKey: .seq)

            try container.encode(did, forKey: .did)

            try container.encode(time, forKey: .time)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(handle, forKey: .handle)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(seq)
            hasher.combine(did)
            hasher.combine(time)
            if let value = handle {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if seq != other.seq {
                return false
            }

            if did != other.did {
                return false
            }

            if time != other.time {
                return false
            }

            if handle != other.handle {
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

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let seqValue = try seq.toCBORValue()
            map = map.adding(key: "seq", value: seqValue)

            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)

            let timeValue = try time.toCBORValue()
            map = map.adding(key: "time", value: timeValue)

            if let value = handle {
                // Encode optional property even if it's an empty array for CBOR

                let handleValue = try value.toCBORValue()
                map = map.adding(key: "handle", value: handleValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case seq
            case did
            case time
            case handle
        }
    }

    public struct Account: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.sync.subscribeRepos#account"
        public let seq: Int
        public let did: DID
        public let time: ATProtocolDate
        public let active: Bool
        public let status: String?

        // Standard initializer
        public init(
            seq: Int, did: DID, time: ATProtocolDate, active: Bool, status: String?
        ) {
            self.seq = seq
            self.did = did
            self.time = time
            self.active = active
            self.status = status
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                seq = try container.decode(Int.self, forKey: .seq)

            } catch {
                LogManager.logError("Decoding error for required property 'seq': \(error)")

                throw error
            }
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")

                throw error
            }
            do {
                time = try container.decode(ATProtocolDate.self, forKey: .time)

            } catch {
                LogManager.logError("Decoding error for required property 'time': \(error)")

                throw error
            }
            do {
                active = try container.decode(Bool.self, forKey: .active)

            } catch {
                LogManager.logError("Decoding error for required property 'active': \(error)")

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

            try container.encode(seq, forKey: .seq)

            try container.encode(did, forKey: .did)

            try container.encode(time, forKey: .time)

            try container.encode(active, forKey: .active)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(seq)
            hasher.combine(did)
            hasher.combine(time)
            hasher.combine(active)
            if let value = status {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if seq != other.seq {
                return false
            }

            if did != other.did {
                return false
            }

            if time != other.time {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let seqValue = try seq.toCBORValue()
            map = map.adding(key: "seq", value: seqValue)

            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)

            let timeValue = try time.toCBORValue()
            map = map.adding(key: "time", value: timeValue)

            let activeValue = try active.toCBORValue()
            map = map.adding(key: "active", value: activeValue)

            if let value = status {
                // Encode optional property even if it's an empty array for CBOR

                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case seq
            case did
            case time
            case active
            case status
        }
    }

    public struct Info: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.sync.subscribeRepos#info"
        public let name: String
        public let message: String?

        // Standard initializer
        public init(
            name: String, message: String?
        ) {
            self.name = name
            self.message = message
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                name = try container.decode(String.self, forKey: .name)

            } catch {
                LogManager.logError("Decoding error for required property 'name': \(error)")

                throw error
            }
            do {
                message = try container.decodeIfPresent(String.self, forKey: .message)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'message': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(name, forKey: .name)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(message, forKey: .message)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            if let value = message {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if name != other.name {
                return false
            }

            if message != other.message {
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

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let nameValue = try name.toCBORValue()
            map = map.adding(key: "name", value: nameValue)

            if let value = message {
                // Encode optional property even if it's an empty array for CBOR

                let messageValue = try value.toCBORValue()
                map = map.adding(key: "message", value: messageValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case name
            case message
        }
    }

    public struct RepoOp: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.sync.subscribeRepos#repoOp"
        public let action: String
        public let path: String
        public let cid: CID
        public let prev: CID?

        // Standard initializer
        public init(
            action: String, path: String, cid: CID, prev: CID?
        ) {
            self.action = action
            self.path = path
            self.cid = cid
            self.prev = prev
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                action = try container.decode(String.self, forKey: .action)

            } catch {
                LogManager.logError("Decoding error for required property 'action': \(error)")

                throw error
            }
            do {
                path = try container.decode(String.self, forKey: .path)

            } catch {
                LogManager.logError("Decoding error for required property 'path': \(error)")

                throw error
            }
            do {
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")

                throw error
            }
            do {
                prev = try container.decodeIfPresent(CID.self, forKey: .prev)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'prev': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(action, forKey: .action)

            try container.encode(path, forKey: .path)

            try container.encode(cid, forKey: .cid)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(prev, forKey: .prev)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(action)
            hasher.combine(path)
            hasher.combine(cid)
            if let value = prev {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if action != other.action {
                return false
            }

            if path != other.path {
                return false
            }

            if cid != other.cid {
                return false
            }

            if prev != other.prev {
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

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)

            let pathValue = try path.toCBORValue()
            map = map.adding(key: "path", value: pathValue)

            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)

            if let value = prev {
                // Encode optional property even if it's an empty array for CBOR

                let prevValue = try value.toCBORValue()
                map = map.adding(key: "prev", value: prevValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case action
            case path
            case cid
            case prev
        }
    }

    public struct Parameters: Parametrizable {
        public let cursor: Int?

        public init(
            cursor: Int? = nil
        ) {
            self.cursor = cursor
        }
    }

    public enum Message: Codable, Sendable {
        case commit(Commit)

        case sync(Sync)

        case identity(Identity)

        case account(Account)

        case info(Info)

        enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "com.atproto.sync.subscribeRepos#commit":
                let value = try Commit(from: decoder)
                self = .commit(value)

            case "com.atproto.sync.subscribeRepos#sync":
                let value = try Sync(from: decoder)
                self = .sync(value)

            case "com.atproto.sync.subscribeRepos#identity":
                let value = try Identity(from: decoder)
                self = .identity(value)

            case "com.atproto.sync.subscribeRepos#account":
                let value = try Account(from: decoder)
                self = .account(value)

            case "com.atproto.sync.subscribeRepos#info":
                let value = try Info(from: decoder)
                self = .info(value)

            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown message type: \(type)"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            switch self {
            case let .commit(value):
                try value.encode(to: encoder)

            case let .sync(value):
                try value.encode(to: encoder)

            case let .identity(value):
                try value.encode(to: encoder)

            case let .account(value):
                try value.encode(to: encoder)

            case let .info(value):
                try value.encode(to: encoder)
            }
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case futureCursor = "FutureCursor."
        case consumerTooSlow = "ConsumerTooSlow.If the consumer of the stream can not keep up with events, and a backlog gets too large, the server will drop the connection."
        public var description: String {
            return rawValue
        }
    }
}

/// Repository event stream, aka Firehose endpoint. Outputs repo commits with diff data, and identity update events, for all repositories on the current server. See the atproto specifications for details around stream sequencing, repo versioning, CAR diff format, and more. Public and does not require auth; implemented by PDS and Relay.

public extension ATProtoClient.Com.Atproto.Sync {
    func subscribeRepos(
        cursor: Int? = nil
    ) async throws -> AsyncThrowingStream<ComAtprotoSyncSubscribeRepos.Message, Error> {
        let params = ComAtprotoSyncSubscribeRepos.Parameters(cursor: cursor)
        return try await networkService.subscribe(
            endpoint: "com.atproto.sync.subscribeRepos",
            parameters: params
        )
    }
}
