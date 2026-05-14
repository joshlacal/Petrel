import Foundation



// lexicon: 1, id: place.stream.multistream.defs


public struct PlaceStreamMultistreamDefs { 

    public static let typeIdentifier = "place.stream.multistream.defs"
        
public struct TargetView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.multistream.defs#targetView"
            public let uri: ATProtocolURI
            public let cid: CID
            public let record: ATProtocolValueContainer
            public let latestEvent: PlaceStreamMultistreamDefs.Event?

        public init(
            uri: ATProtocolURI, cid: CID, record: ATProtocolValueContainer, latestEvent: PlaceStreamMultistreamDefs.Event?
        ) {
            self.uri = uri
            self.cid = cid
            self.record = record
            self.latestEvent = latestEvent
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                throw error
            }
            do {
                self.cid = try container.decode(CID.self, forKey: .cid)
            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                throw error
            }
            do {
                self.record = try container.decode(ATProtocolValueContainer.self, forKey: .record)
            } catch {
                LogManager.logError("Decoding error for required property 'record': \(error)")
                throw error
            }
            do {
                self.latestEvent = try container.decodeIfPresent(PlaceStreamMultistreamDefs.Event.self, forKey: .latestEvent)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'latestEvent': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encode(cid, forKey: .cid)
            try container.encode(record, forKey: .record)
            try container.encodeIfPresent(latestEvent, forKey: .latestEvent)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(record)
            if let value = latestEvent {
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
            if record != other.record {
                return false
            }
            if latestEvent != other.latestEvent {
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
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            if let value = latestEvent {
                let latestEventValue = try value.toCBORValue()
                map = map.adding(key: "latestEvent", value: latestEventValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case record
            case latestEvent
        }
    }
        
public struct Event: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.multistream.defs#event"
            public let message: String
            public let status: String
            public let createdAt: ATProtocolDate

        public init(
            message: String, status: String, createdAt: ATProtocolDate
        ) {
            self.message = message
            self.status = status
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.message = try container.decode(String.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                self.status = try container.decode(String.self, forKey: .status)
            } catch {
                LogManager.logError("Decoding error for required property 'status': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(message, forKey: .message)
            try container.encode(status, forKey: .status)
            try container.encode(createdAt, forKey: .createdAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(message)
            hasher.combine(status)
            hasher.combine(createdAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if message != other.message {
                return false
            }
            if status != other.status {
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case message
            case status
            case createdAt
        }
    }



}


                           

