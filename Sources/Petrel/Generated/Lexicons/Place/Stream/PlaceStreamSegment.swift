import Foundation



// lexicon: 1, id: place.stream.segment


public struct PlaceStreamSegment: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.segment"
        public let id: String
        public let signingKey: String
        public let startTime: ATProtocolDate
        public let duration: Int?
        public let creator: DID
        public let video: [Video]?
        public let audio: [Audio]?
        public let size: Int?
        public let contentWarnings: PlaceStreamMetadataContentWarnings?
        public let contentRights: PlaceStreamMetadataContentRights?
        public let distributionPolicy: PlaceStreamMetadataDistributionPolicy?

        public init(id: String, signingKey: String, startTime: ATProtocolDate, duration: Int?, creator: DID, video: [Video]?, audio: [Audio]?, size: Int?, contentWarnings: PlaceStreamMetadataContentWarnings?, contentRights: PlaceStreamMetadataContentRights?, distributionPolicy: PlaceStreamMetadataDistributionPolicy?) {
            self.id = id
            self.signingKey = signingKey
            self.startTime = startTime
            self.duration = duration
            self.creator = creator
            self.video = video
            self.audio = audio
            self.size = size
            self.contentWarnings = contentWarnings
            self.contentRights = contentRights
            self.distributionPolicy = distributionPolicy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(String.self, forKey: .id)
            self.signingKey = try container.decode(String.self, forKey: .signingKey)
            self.startTime = try container.decode(ATProtocolDate.self, forKey: .startTime)
            self.duration = try container.decodeIfPresent(Int.self, forKey: .duration)
            self.creator = try container.decode(DID.self, forKey: .creator)
            self.video = try container.decodeIfPresent([Video].self, forKey: .video)
            self.audio = try container.decodeIfPresent([Audio].self, forKey: .audio)
            self.size = try container.decodeIfPresent(Int.self, forKey: .size)
            self.contentWarnings = try container.decodeIfPresent(PlaceStreamMetadataContentWarnings.self, forKey: .contentWarnings)
            self.contentRights = try container.decodeIfPresent(PlaceStreamMetadataContentRights.self, forKey: .contentRights)
            self.distributionPolicy = try container.decodeIfPresent(PlaceStreamMetadataDistributionPolicy.self, forKey: .distributionPolicy)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(signingKey, forKey: .signingKey)
            try container.encode(startTime, forKey: .startTime)
            try container.encodeIfPresent(duration, forKey: .duration)
            try container.encode(creator, forKey: .creator)
            try container.encodeIfPresent(video, forKey: .video)
            try container.encodeIfPresent(audio, forKey: .audio)
            try container.encodeIfPresent(size, forKey: .size)
            try container.encodeIfPresent(contentWarnings, forKey: .contentWarnings)
            try container.encodeIfPresent(contentRights, forKey: .contentRights)
            try container.encodeIfPresent(distributionPolicy, forKey: .distributionPolicy)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if id != other.id {
                return false
            }
            if signingKey != other.signingKey {
                return false
            }
            if startTime != other.startTime {
                return false
            }
            if duration != other.duration {
                return false
            }
            if creator != other.creator {
                return false
            }
            if video != other.video {
                return false
            }
            if audio != other.audio {
                return false
            }
            if size != other.size {
                return false
            }
            if contentWarnings != other.contentWarnings {
                return false
            }
            if contentRights != other.contentRights {
                return false
            }
            if distributionPolicy != other.distributionPolicy {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(signingKey)
            hasher.combine(startTime)
            if let value = duration {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(creator)
            if let value = video {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = audio {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = size {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = contentWarnings {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = contentRights {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = distributionPolicy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            let signingKeyValue = try signingKey.toCBORValue()
            map = map.adding(key: "signingKey", value: signingKeyValue)
            let startTimeValue = try startTime.toCBORValue()
            map = map.adding(key: "startTime", value: startTimeValue)
            if let value = duration {
                let durationValue = try value.toCBORValue()
                map = map.adding(key: "duration", value: durationValue)
            }
            let creatorValue = try creator.toCBORValue()
            map = map.adding(key: "creator", value: creatorValue)
            if let value = video {
                let videoValue = try value.toCBORValue()
                map = map.adding(key: "video", value: videoValue)
            }
            if let value = audio {
                let audioValue = try value.toCBORValue()
                map = map.adding(key: "audio", value: audioValue)
            }
            if let value = size {
                let sizeValue = try value.toCBORValue()
                map = map.adding(key: "size", value: sizeValue)
            }
            if let value = contentWarnings {
                let contentWarningsValue = try value.toCBORValue()
                map = map.adding(key: "contentWarnings", value: contentWarningsValue)
            }
            if let value = contentRights {
                let contentRightsValue = try value.toCBORValue()
                map = map.adding(key: "contentRights", value: contentRightsValue)
            }
            if let value = distributionPolicy {
                let distributionPolicyValue = try value.toCBORValue()
                map = map.adding(key: "distributionPolicy", value: distributionPolicyValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case signingKey
            case startTime
            case duration
            case creator
            case video
            case audio
            case size
            case contentWarnings
            case contentRights
            case distributionPolicy
        }
        
public struct Audio: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.segment#audio"
            public let codec: String
            public let rate: Int
            public let channels: Int

        public init(
            codec: String, rate: Int, channels: Int
        ) {
            self.codec = codec
            self.rate = rate
            self.channels = channels
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.codec = try container.decode(String.self, forKey: .codec)
            } catch {
                LogManager.logError("Decoding error for required property 'codec': \(error)")
                throw error
            }
            do {
                self.rate = try container.decode(Int.self, forKey: .rate)
            } catch {
                LogManager.logError("Decoding error for required property 'rate': \(error)")
                throw error
            }
            do {
                self.channels = try container.decode(Int.self, forKey: .channels)
            } catch {
                LogManager.logError("Decoding error for required property 'channels': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(codec, forKey: .codec)
            try container.encode(rate, forKey: .rate)
            try container.encode(channels, forKey: .channels)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(codec)
            hasher.combine(rate)
            hasher.combine(channels)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if codec != other.codec {
                return false
            }
            if rate != other.rate {
                return false
            }
            if channels != other.channels {
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
            let codecValue = try codec.toCBORValue()
            map = map.adding(key: "codec", value: codecValue)
            let rateValue = try rate.toCBORValue()
            map = map.adding(key: "rate", value: rateValue)
            let channelsValue = try channels.toCBORValue()
            map = map.adding(key: "channels", value: channelsValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case codec
            case rate
            case channels
        }
    }
        
public struct Video: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.segment#video"
            public let codec: String
            public let width: Int
            public let height: Int
            public let framerate: Framerate?
            public let bframes: Bool?

        public init(
            codec: String, width: Int, height: Int, framerate: Framerate?, bframes: Bool?
        ) {
            self.codec = codec
            self.width = width
            self.height = height
            self.framerate = framerate
            self.bframes = bframes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.codec = try container.decode(String.self, forKey: .codec)
            } catch {
                LogManager.logError("Decoding error for required property 'codec': \(error)")
                throw error
            }
            do {
                self.width = try container.decode(Int.self, forKey: .width)
            } catch {
                LogManager.logError("Decoding error for required property 'width': \(error)")
                throw error
            }
            do {
                self.height = try container.decode(Int.self, forKey: .height)
            } catch {
                LogManager.logError("Decoding error for required property 'height': \(error)")
                throw error
            }
            do {
                self.framerate = try container.decodeIfPresent(Framerate.self, forKey: .framerate)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'framerate': \(error)")
                throw error
            }
            do {
                self.bframes = try container.decodeIfPresent(Bool.self, forKey: .bframes)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'bframes': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(codec, forKey: .codec)
            try container.encode(width, forKey: .width)
            try container.encode(height, forKey: .height)
            try container.encodeIfPresent(framerate, forKey: .framerate)
            try container.encodeIfPresent(bframes, forKey: .bframes)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(codec)
            hasher.combine(width)
            hasher.combine(height)
            if let value = framerate {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = bframes {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if codec != other.codec {
                return false
            }
            if width != other.width {
                return false
            }
            if height != other.height {
                return false
            }
            if framerate != other.framerate {
                return false
            }
            if bframes != other.bframes {
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
            let codecValue = try codec.toCBORValue()
            map = map.adding(key: "codec", value: codecValue)
            let widthValue = try width.toCBORValue()
            map = map.adding(key: "width", value: widthValue)
            let heightValue = try height.toCBORValue()
            map = map.adding(key: "height", value: heightValue)
            if let value = framerate {
                let framerateValue = try value.toCBORValue()
                map = map.adding(key: "framerate", value: framerateValue)
            }
            if let value = bframes {
                let bframesValue = try value.toCBORValue()
                map = map.adding(key: "bframes", value: bframesValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case codec
            case width
            case height
            case framerate
            case bframes
        }
    }
        
public struct Framerate: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.segment#framerate"
            public let num: Int
            public let den: Int

        public init(
            num: Int, den: Int
        ) {
            self.num = num
            self.den = den
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.num = try container.decode(Int.self, forKey: .num)
            } catch {
                LogManager.logError("Decoding error for required property 'num': \(error)")
                throw error
            }
            do {
                self.den = try container.decode(Int.self, forKey: .den)
            } catch {
                LogManager.logError("Decoding error for required property 'den': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(num, forKey: .num)
            try container.encode(den, forKey: .den)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(num)
            hasher.combine(den)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if num != other.num {
                return false
            }
            if den != other.den {
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
            let numValue = try num.toCBORValue()
            map = map.adding(key: "num", value: numValue)
            let denValue = try den.toCBORValue()
            map = map.adding(key: "den", value: denValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case num
            case den
        }
    }
        
public struct SegmentView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.segment#segmentView"
            public let cid: CID
            public let record: ATProtocolValueContainer

        public init(
            cid: CID, record: ATProtocolValueContainer
        ) {
            self.cid = cid
            self.record = record
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
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
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cid, forKey: .cid)
            try container.encode(record, forKey: .record)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cid)
            hasher.combine(record)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cid != other.cid {
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cid
            case record
        }
    }



}


                           

