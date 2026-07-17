import Foundation

enum DAGCBORJSONBridge {
    enum UnsignedIntegerPolicy {
        case exactJSONNumber
        case stringifyAboveIntMax
    }

    static func jsonCompatibleValue(
        from value: Any,
        unsignedIntegerPolicy: UnsignedIntegerPolicy = .exactJSONNumber
    ) throws -> Any {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let wrapped = mirror.children.first?.value else {
                return NSNull()
            }
            return try jsonCompatibleValue(
                from: wrapped,
                unsignedIntegerPolicy: unsignedIntegerPolicy
            )
        }

        switch value {
        case is NSNull:
            return NSNull()
        case let cid as CID:
            return ["$link": cid.string]
        case let data as Data:
            return ["$bytes": data.base64EncodedString()]
        case let dictionary as [String: Any]:
            var result: [String: Any] = [:]
            result.reserveCapacity(dictionary.count)
            for (key, nestedValue) in dictionary {
                result[key] = try jsonCompatibleValue(
                    from: nestedValue,
                    unsignedIntegerPolicy: unsignedIntegerPolicy
                )
            }
            return result
        case let array as [Any]:
            return try array.map {
                try jsonCompatibleValue(
                    from: $0,
                    unsignedIntegerPolicy: unsignedIntegerPolicy
                )
            }
        case let bool as Bool:
            return bool
        case let string as String:
            return string
        case let int as Int:
            return NSNumber(value: int)
        case let int8 as Int8:
            return NSNumber(value: int8)
        case let int16 as Int16:
            return NSNumber(value: int16)
        case let int32 as Int32:
            return NSNumber(value: int32)
        case let int64 as Int64:
            return NSNumber(value: int64)
        case let uint as UInt:
            return compatibleUnsignedInteger(UInt64(uint), policy: unsignedIntegerPolicy)
        case let uint8 as UInt8:
            return compatibleUnsignedInteger(UInt64(uint8), policy: unsignedIntegerPolicy)
        case let uint16 as UInt16:
            return compatibleUnsignedInteger(UInt64(uint16), policy: unsignedIntegerPolicy)
        case let uint32 as UInt32:
            return compatibleUnsignedInteger(UInt64(uint32), policy: unsignedIntegerPolicy)
        case let uint64 as UInt64:
            return compatibleUnsignedInteger(uint64, policy: unsignedIntegerPolicy)
        default:
            throw DAGCBORError.decodingFailed(
                "Unsupported DAG-CBOR JSON bridge value: \(String(describing: type(of: value)))"
            )
        }
    }

    static func jsonData(
        from value: Any,
        unsignedIntegerPolicy: UnsignedIntegerPolicy = .exactJSONNumber
    ) throws -> Data {
        let compatibleValue = try jsonCompatibleValue(
            from: value,
            unsignedIntegerPolicy: unsignedIntegerPolicy
        )
        return try JSONSerialization.data(
            withJSONObject: compatibleValue,
            options: [.fragmentsAllowed]
        )
    }

    private static func compatibleUnsignedInteger(
        _ value: UInt64,
        policy: UnsignedIntegerPolicy
    ) -> Any {
        switch policy {
        case .exactJSONNumber:
            return NSNumber(value: value)
        case .stringifyAboveIntMax:
            if value > UInt64(Int.max) {
                return String(value)
            }
            return NSNumber(value: value)
        }
    }
}
