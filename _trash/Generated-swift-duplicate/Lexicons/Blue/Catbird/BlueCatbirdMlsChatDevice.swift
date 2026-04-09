import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.device


public struct BlueCatbirdMlsChatDevice: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "blue.catbird.mlsChat.device"
        public let mlsSignaturePublicKey: Bytes
        public let algorithm: String
        public let createdAt: ATProtocolDate

        public init(mlsSignaturePublicKey: Bytes, algorithm: String, createdAt: ATProtocolDate) {
            self.mlsSignaturePublicKey = mlsSignaturePublicKey
            self.algorithm = algorithm
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.mlsSignaturePublicKey = try container.decode(Bytes.self, forKey: .mlsSignaturePublicKey)
            self.algorithm = try container.decode(String.self, forKey: .algorithm)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(mlsSignaturePublicKey, forKey: .mlsSignaturePublicKey)
            try container.encode(algorithm, forKey: .algorithm)
            try container.encode(createdAt, forKey: .createdAt)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if mlsSignaturePublicKey != other.mlsSignaturePublicKey {
                return false
            }
            if algorithm != other.algorithm {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(mlsSignaturePublicKey)
            hasher.combine(algorithm)
            hasher.combine(createdAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let mlsSignaturePublicKeyValue = try mlsSignaturePublicKey.toCBORValue()
            map = map.adding(key: "mlsSignaturePublicKey", value: mlsSignaturePublicKeyValue)
            let algorithmValue = try algorithm.toCBORValue()
            map = map.adding(key: "algorithm", value: algorithmValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case mlsSignaturePublicKey
            case algorithm
            case createdAt
        }



}


                           

