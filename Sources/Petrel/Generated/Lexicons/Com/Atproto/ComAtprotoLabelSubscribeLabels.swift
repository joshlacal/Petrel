import Foundation



// lexicon: 1, id: com.atproto.label.subscribeLabels


public struct ComAtprotoLabelSubscribeLabels { 

    public static let typeIdentifier = "com.atproto.label.subscribeLabels"
        
public struct Labels: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.label.subscribeLabels#labels"
            public let seq: Int
            public let labels: [ComAtprotoLabelDefs.Label]

        // Standard initializer
        public init(
            seq: Int, labels: [ComAtprotoLabelDefs.Label]
        ) {
            
            self.seq = seq
            self.labels = labels
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.seq = try container.decode(Int.self, forKey: .seq)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'seq': \(error)")
                
                throw error
            }
            do {
                
                
                self.labels = try container.decode([ComAtprotoLabelDefs.Label].self, forKey: .labels)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'labels': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(seq, forKey: .seq)
            
            
            
            
            try container.encode(labels, forKey: .labels)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(seq)
            hasher.combine(labels)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.seq != other.seq {
                return false
            }
            
            
            
            
            if self.labels != other.labels {
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
            
            
            
            
            
            
            let labelsValue = try labels.toCBORValue()
            map = map.adding(key: "labels", value: labelsValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case seq
            case labels
        }
    }
        
public struct Info: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.label.subscribeLabels#info"
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
                
                
                self.name = try container.decode(String.self, forKey: .name)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'name': \(error)")
                
                throw error
            }
            do {
                
                
                self.message = try container.decodeIfPresent(String.self, forKey: .message)
                
                
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
            
            
            if self.name != other.name {
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
public struct Parameters: Parametrizable {
        public let cursor: Int?
        
        public init(
            cursor: Int? = nil
            ) {
            self.cursor = cursor
            
        }
    }
public enum Message: Codable, Sendable {

    case labels(Labels)

    case info(Info)


    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {

        case "com.atproto.label.subscribeLabels#labels":
            let value = try Labels(from: decoder)
            self = .labels(value)

        case "com.atproto.label.subscribeLabels#info":
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

        case .labels(let value):
            try value.encode(to: encoder)

        case .info(let value):
            try value.encode(to: encoder)

        }
    }
}        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case futureCursor = "FutureCursor."
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}


                           

/// Subscribe to stream of labels (and negations). Public endpoint implemented by mod services. Uses same sequencing scheme as repo event stream.

extension ATProtoClient.Com.Atproto.Label {
    
    public func subscribeLabels(
        cursor: Int? = nil
    ) async throws -> AsyncThrowingStream<ComAtprotoLabelSubscribeLabels.Message, Error> {
        let params = ComAtprotoLabelSubscribeLabels.Parameters(cursor: cursor)
        return try await self.networkService.subscribe(
            endpoint: "com.atproto.label.subscribeLabels",
            parameters: params
        )
    }

    /// Alternative signature accepting input struct
    public func subscribeLabels(input: ComAtprotoLabelSubscribeLabels.Parameters) async throws -> AsyncThrowingStream<ComAtprotoLabelSubscribeLabels.Message, Error> {
        return try await self.networkService.subscribe(
            endpoint: "com.atproto.label.subscribeLabels",
            parameters: input
        )
    }
    
}
