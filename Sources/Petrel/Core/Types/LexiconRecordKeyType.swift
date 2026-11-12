import Foundation

/// The record key type a `record` Lexicon declares in its `key` field.
///
/// Generated record types expose it as `recordKeyType`, so code that writes records can
/// pick or check a record key without re-reading the Lexicon:
///
/// ```swift
/// AppBskyFeedPost.recordKeyType                    // .tid
/// AppBskyActorProfile.recordKeyType                // .literal("self")
/// AppBskyActorProfile.recordKeyType.accepts("self") // true
/// ```
public enum LexiconRecordKeyType: Sendable, Equatable, Hashable {
    /// `tid`: a timestamp identifier.
    case tid
    /// `nsid`: the record key is an NSID.
    case nsid
    /// `any`: any string that satisfies the record-key syntax.
    case any
    /// `literal:<value>`: exactly one record with this key may exist.
    case literal(String)
    /// A key type this version of Petrel does not know. Only the record-key syntax is checked.
    case other(String)

    /// Parses the `key` value of a record Lexicon (`tid`, `nsid`, `any`, `literal:self`, …).
    public init(lexiconValue: String) {
        switch lexiconValue {
        case "tid": self = .tid
        case "nsid": self = .nsid
        case "any": self = .any
        default:
            if lexiconValue.hasPrefix("literal:") {
                self = .literal(String(lexiconValue.dropFirst("literal:".count)))
            } else {
                self = .other(lexiconValue)
            }
        }
    }

    /// The value as written in the Lexicon.
    public var lexiconValue: String {
        switch self {
        case .tid: "tid"
        case .nsid: "nsid"
        case .any: "any"
        case let .literal(value): "literal:\(value)"
        case let .other(value): value
        }
    }

    /// Whether `recordKey` is a valid record key for a collection of this key type.
    ///
    /// Every key must satisfy the generic record-key syntax; `tid`, `nsid` and `literal`
    /// add their own rule on top.
    public func accepts(_ recordKey: String) -> Bool {
        guard (try? RecordKey(keyString: recordKey)) != nil else { return false }
        switch self {
        case .tid:
            return (try? TID(tidString: recordKey)) != nil
        case .nsid:
            return (try? NSID(nsidString: recordKey)) != nil
        case let .literal(value):
            return recordKey == value
        case .any, .other:
            return true
        }
    }
}
