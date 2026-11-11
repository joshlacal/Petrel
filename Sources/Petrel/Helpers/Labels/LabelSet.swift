import Foundation
import SwiftCBOR

public extension ComAtprotoLabelDefs.Label {
    /// Whether this label retracts an earlier label with the same source, subject and value.
    var isNegation: Bool {
        neg == true
    }

    /// Whether this label has passed its expiration time.
    func isExpired(at now: Date = Date()) -> Bool {
        guard let exp else { return false }
        return exp.date <= now
    }

    /// Whether this label should be applied: it is neither a negation nor expired.
    ///
    /// The label specification asks consumers not to act on negated or expired
    /// labels. Labels hydrated by an AppView are already filtered this way;
    /// labels read from `com.atproto.label.queryLabels` or a
    /// `subscribeLabels` stream are not.
    func isActive(at now: Date = Date()) -> Bool {
        !isNegation && !isExpired(at: now)
    }
}

/// The current state of a stream of labels: the latest label for each
/// (source, subject, value), with negations and expirations applied.
///
/// Feed it labels from `com.atproto.label.subscribeLabels` or
/// `queryLabels`; read back only the labels that are in force.
///
/// ```swift
/// var labels = LabelSet()
/// for try await message in try await labeler.com.atproto.label.subscribeLabels(cursor: labels.cursor) {
///     labels.apply(LabelStreamEvent(message))
/// }
/// let active = labels.activeLabels(for: "at://did:plc:abc/app.bsky.feed.post/3kabc")
/// ```
public struct LabelSet: Sendable {
    /// What identifies a label for the purposes of replacement and negation.
    public struct Key: Sendable, Hashable {
        /// The labeler that issued the label.
        public let src: DID
        /// The subject: an `at://` record URI or an account DID.
        public let uri: String
        /// The label value.
        public let val: String

        /// Creates a key.
        public init(src: DID, uri: String, val: String) {
            self.src = src
            self.uri = uri
            self.val = val
        }

        /// The key of a label.
        public init(_ label: ComAtprotoLabelDefs.Label) {
            self.init(src: label.src, uri: label.uri.uriString(), val: label.val)
        }
    }

    /// The most recent label per key. A stored negation is a tombstone that
    /// keeps an older, late-arriving label from resurrecting the retracted one.
    private var latest: [Key: ComAtprotoLabelDefs.Label] = [:]

    /// The sequence number of the last stream event applied, for resuming a subscription.
    public private(set) var cursor: Int?

    /// Creates an empty set.
    public init() {}

    /// Applies one label.
    ///
    /// A label replaces the stored one for its key unless it is older (by
    /// creation time). A negation therefore retracts an earlier label, and a
    /// later re-issue reinstates it.
    ///
    /// - Returns: Whether the label was taken (it was not older than the stored one).
    @discardableResult
    public mutating func apply(_ label: ComAtprotoLabelDefs.Label) -> Bool {
        let key = Key(label)
        if let stored = latest[key], stored.cts.date > label.cts.date {
            return false
        }
        latest[key] = label
        return true
    }

    /// Applies a stream event: its labels in order, then its sequence number.
    public mutating func apply(_ event: LabelStreamEvent) {
        guard case let .labels(seq, labels) = event else { return }
        for label in labels {
            apply(label)
        }
        cursor = seq
    }

    /// Applies a stream event if there is one; ignored frames decode to `nil`.
    public mutating func apply(_ event: LabelStreamEvent?) {
        if let event {
            apply(event)
        }
    }

    /// Every label in force at `now`: not negated and not expired.
    public func activeLabels(at now: Date = Date()) -> [ComAtprotoLabelDefs.Label] {
        latest.values.filter { $0.isActive(at: now) }.sorted(by: Self.inOrder)
    }

    /// The labels in force on one subject.
    /// - Parameters:
    ///   - uri: An `at://` record URI or an account DID.
    ///   - now: The moment expiry is judged at.
    public func activeLabels(for uri: String, at now: Date = Date()) -> [ComAtprotoLabelDefs.Label] {
        latest.values.filter { $0.uri.uriString() == uri && $0.isActive(at: now) }.sorted(by: Self.inOrder)
    }

    /// Drops negations and expired labels that no longer need to be remembered.
    ///
    /// Tombstones older than `olderThan` are removed. Keep them for as long as
    /// the stream may replay events, or a replayed label would reappear.
    public mutating func prune(at now: Date = Date(), olderThan: Date) {
        latest = latest.filter { _, label in
            label.isActive(at: now) || label.cts.date >= olderThan
        }
    }

    private static func inOrder(_ lhs: ComAtprotoLabelDefs.Label, _ rhs: ComAtprotoLabelDefs.Label) -> Bool {
        (lhs.uri.uriString(), lhs.src.didString(), lhs.val) < (rhs.uri.uriString(), rhs.src.didString(), rhs.val)
    }
}

/// One event of a `com.atproto.label.subscribeLabels` stream.
public enum LabelStreamEvent: Sendable, Equatable {
    /// A batch of labels with the stream sequence number it was sent at.
    case labels(seq: Int, labels: [ComAtprotoLabelDefs.Label])
    /// An informational message, for example `OutdatedCursor`.
    case info(name: String, message: String?)

    /// Converts a message of the generated subscription.
    public init(_ message: ComAtprotoLabelSubscribeLabels.Message) {
        switch message {
        case let .labels(labels):
            self = .labels(seq: labels.seq, labels: labels.labels)
        case let .info(info):
            self = .info(name: info.name, message: info.message)
        }
    }
}

/// Decodes raw `subscribeLabels` WebSocket frames, skipping the frames a
/// client is required to ignore.
///
/// The event stream specification says clients should ignore frames whose
/// header has an unknown `op` or `t`, while malformed framing is a hard
/// error. ``decode(frame:)`` returns `nil` for the former and throws for the
/// latter, so a consumer can keep its connection across protocol additions.
public enum LabelStreamDecoder {
    private static let lexicon = "com.atproto.label.subscribeLabels"

    /// Decodes one binary frame.
    ///
    /// - Returns: The event, or `nil` when the frame has an unknown `op` or
    ///   message type and must be ignored.
    /// - Throws: When the frame is not valid framing, carries an error
    ///   (`op` = -1), or its payload does not match the lexicon.
    public static func decode(frame: Data) throws -> LabelStreamEvent? {
        guard let header = try? CBOR.decode([UInt8](frame)), case let .map(fields) = header else {
            throw NetworkError.invalidResponse(description: "Label stream frame has no CBOR header map")
        }
        switch fields[.utf8String("op")] {
        case .unsignedInt(1):
            break
        case .negativeInt(0):
            // An error frame ends the stream; the frame decoder turns it into a thrown error.
            _ = try ATProtoWebSocketFrameDecoder.decodeFrame(frame, defaultLexicon: lexicon)
            throw NetworkError.invalidResponse(description: "Label stream sent an error frame")
        case .some(.unsignedInt), .some(.negativeInt):
            return nil // Unknown operation: ignore the frame.
        default:
            throw NetworkError.invalidResponse(description: "Label stream frame header has no integer op")
        }
        guard case let .utf8String(type)? = fields[.utf8String("t")] else {
            throw NetworkError.invalidResponse(description: "Label stream message frame has no type")
        }
        guard type == "#labels" || type == "#info" else {
            return nil // Unknown message type: ignore the frame.
        }

        let decoded = try ATProtoWebSocketFrameDecoder.decodeFrame(frame, defaultLexicon: lexicon)
        let decoder = JSONDecoder()
        if type == "#labels" {
            let labels = try decoder.decode(ComAtprotoLabelSubscribeLabels.Labels.self, from: decoded.jsonData)
            return .labels(seq: labels.seq, labels: labels.labels)
        }
        let info = try decoder.decode(ComAtprotoLabelSubscribeLabels.Info.self, from: decoded.jsonData)
        return .info(name: info.name, message: info.message)
    }
}
