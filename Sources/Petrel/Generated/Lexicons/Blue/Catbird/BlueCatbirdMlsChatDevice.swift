import Foundation




// lexicon: 1, id: blue.catbird.mlsChat.device


public struct BlueCatbirdMlsChatDevice: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "blue.catbird.mlsChat.device"
        public let deviceId: String
        public let deviceName: String?
        public let mlsSignaturePublicKey: Bytes
        public let algorithm: String
        public let platform: String?
        public let createdAt: ATProtocolDate

        public init(deviceId: String, deviceName: String?, mlsSignaturePublicKey: Bytes, algorithm: String, platform: String?, createdAt: ATProtocolDate) {
            self.deviceId = deviceId
            self.deviceName = deviceName
            self.mlsSignaturePublicKey = mlsSignaturePublicKey
            self.algorithm = algorithm
            self.platform = platform
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.deviceId = try container.decode(String.self, forKey: .deviceId)
            self.deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
            self.mlsSignaturePublicKey = try container.decode(Bytes.self, forKey: .mlsSignaturePublicKey)
            self.algorithm = try container.decode(String.self, forKey: .algorithm)
            self.platform = try container.decodeIfPresent(String.self, forKey: .platform)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(deviceId, forKey: .deviceId)
            try container.encodeIfPresent(deviceName, forKey: .deviceName)
            try container.encode(mlsSignaturePublicKey, forKey: .mlsSignaturePublicKey)
            try container.encode(algorithm, forKey: .algorithm)
            try container.encodeIfPresent(platform, forKey: .platform)
            try container.encode(createdAt, forKey: .createdAt)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if deviceId != other.deviceId {
                return false
            }
            if deviceName != other.deviceName {
                return false
            }
            if mlsSignaturePublicKey != other.mlsSignaturePublicKey {
                return false
            }
            if algorithm != other.algorithm {
                return false
            }
            if platform != other.platform {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(deviceId)
            if let value = deviceName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(mlsSignaturePublicKey)
            hasher.combine(algorithm)
            if let value = platform {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(createdAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            if let value = deviceName {
                let deviceNameValue = try value.toCBORValue()
                map = map.adding(key: "deviceName", value: deviceNameValue)
            }
            let mlsSignaturePublicKeyValue = try mlsSignaturePublicKey.toCBORValue()
            map = map.adding(key: "mlsSignaturePublicKey", value: mlsSignaturePublicKeyValue)
            let algorithmValue = try algorithm.toCBORValue()
            map = map.adding(key: "algorithm", value: algorithmValue)
            if let value = platform {
                let platformValue = try value.toCBORValue()
                map = map.adding(key: "platform", value: platformValue)
            }
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case deviceId
            case deviceName
            case mlsSignaturePublicKey
            case algorithm
            case platform
            case createdAt
        }



}


                           

