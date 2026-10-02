//
//  IdentifierScanners.swift
//
//  Byte-level fast paths for the hand-written AT Protocol leaf identifiers
//  (DID, Handle, NSID, RecordKey and the public AT-URI grammar).
//
//  Contract: "fast path with exact legacy fallback". A scanner either returns a
//  definitive verdict that is provably identical to the legacy
//  NSRegularExpression validator, or `.undecided`, in which case the caller runs
//  the legacy validator unchanged. Only the definitive direction needs a proof;
//  anything exotic is routed to the legacy code:
//
//  - Non-ASCII input. Legacy validators reject it (DID/NSID/RecordKey via
//    `allSatisfy(\.isASCII)`, Handle via an ASCII-only regex on the original
//    string), so a non-ASCII byte is a definitive `.invalid`.
//  - A trailing line terminator (LF, VT, FF, CR, or CR LF). ICU's non-MULTILINE
//    `$` also matches *before* a final line terminator, so the legacy DID, NSID
//    and RecordKey regexes accept e.g. `did:plc:abc\n`. That quirk is preserved
//    bit-for-bit by answering `.undecided` for such input. Tightening it to the
//    atproto spec is a separate, explicitly logged decision.
//
//  Deployment floor: iOS 18 / macOS 15 / tvOS 18. `String.utf8.span` and
//  `UTF8Span` need iOS/macOS 26, so the bytes come from
//  `utf8.withContiguousStorageIfAvailable` (iOS 8+), with a native copy via
//  `withUTF8` for the rare non-contiguous (bridged) string. With a Swift 6.2+
//  compiler the scanners read through a back-deployed `Span<UInt8>` (the type is
//  available from iOS 12.2 / macOS 10.14.4) constructed with the stdlib's
//  `Span(_unsafeElements:)`; older compilers scan the `UnsafeBufferPointer`
//  directly. Both expose `count` and an `Int` subscript, so the scanner bodies
//  are identical.
//

import Foundation

/// Three-valued verdict of a byte scanner.
@_spi(LeafScanners)
public enum LeafVerdict: UInt8, Sendable {
    case invalid
    case valid
    /// The scanner cannot decide byte-exactly; the legacy validator must run.
    case undecided
}

#if compiler(>=6.2)
    typealias LeafBytes = Span<UInt8>
#else
    typealias LeafBytes = UnsafeBufferPointer<UInt8>
#endif

// MARK: - ASCII classes

@inline(__always) func leafIsLower(_ b: UInt8) -> Bool { b &- 0x61 < 26 }
@inline(__always) func leafIsUpper(_ b: UInt8) -> Bool { b &- 0x41 < 26 }
@inline(__always) func leafIsAlpha(_ b: UInt8) -> Bool { (b | 0x20) &- 0x61 < 26 }
@inline(__always) func leafIsDigit(_ b: UInt8) -> Bool { b &- 0x30 < 10 }
@inline(__always) func leafIsAlnum(_ b: UInt8) -> Bool { leafIsAlpha(b) || leafIsDigit(b) }

/// LF (0x0A), VT (0x0B), FF (0x0C), CR (0x0D): the only ASCII bytes that end an
/// ICU line terminator (CR LF ends in LF).
@inline(__always) func leafIsLineTerminator(_ b: UInt8) -> Bool { b &- 0x0A < 4 }

enum LeafScan {
    // MARK: Byte access

    /// Runs `body` over the string's UTF-8 bytes without copying when the storage is
    /// contiguous (every native and JSONDecoder-produced string), otherwise over a
    /// native copy. The bytes are the same either way, so verdicts never depend on
    /// storage.
    @inline(__always)
    static func withUTF8<R>(_ s: String, _ body: (UnsafeBufferPointer<UInt8>) -> R) -> R {
        if let result = s.utf8.withContiguousStorageIfAvailable(body) {
            return result
        }
        var copy = s
        return copy.withUTF8(body)
    }

    /// Runs `body` over a `LeafBytes` view of the string's UTF-8 bytes.
    @inline(__always)
    static func withBytes<R>(_ s: String, _ body: (LeafBytes) -> R) -> R {
        withUTF8(s) { buffer in
            #if compiler(>=6.2)
                let bytes = unsafe LeafBytes(_unsafeElements: buffer)
            #else
                let bytes = buffer
            #endif
            return body(bytes)
        }
    }

    // MARK: DID  ^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$   (1...2048 bytes, ASCII)

    @inline(__always) static func isDIDBody(_ b: UInt8) -> Bool {
        leafIsAlnum(b) || b == 0x2E || b == 0x5F || b == 0x3A || b == 0x25 || b == 0x2D
    }

    @inline(__always) static func isDIDLast(_ b: UInt8) -> Bool {
        leafIsAlnum(b) || b == 0x2E || b == 0x5F || b == 0x2D
    }

    /// DID grammar over `u[start..<end]`.
    static func did(_ u: LeafBytes, _ start: Int, _ end: Int) -> LeafVerdict {
        let n = end - start
        if n == 0 || n > 2048 { return .invalid }
        if leafIsLineTerminator(u[end - 1]) { return .undecided }
        guard n >= 7,
              u[start] == 0x64, u[start + 1] == 0x69, u[start + 2] == 0x64, u[start + 3] == 0x3A
        else { return .invalid }
        var i = start + 4
        while i < end {
            let b = u[i]
            if !leafIsLower(b) { break }
            i += 1
        }
        // At least one method byte, then ':', then at least one identifier byte.
        guard i > start + 4, i < end - 1, u[i] == 0x3A else { return .invalid }
        i += 1
        while i < end - 1 {
            guard isDIDBody(u[i]) else { return .invalid }
            i += 1
        }
        return isDIDLast(u[end - 1]) ? .valid : .invalid
    }

    // MARK: Handle

    /// Handle grammar over `u[start..<end]`. Always definitive: the legacy label
    /// pre-check rejects every control byte (so ICU's `$` quirk cannot apply), and
    /// the legacy regex runs on the *original* string with ASCII-only classes, so a
    /// non-ASCII byte can never pass even when `lowercased()` folds it to ASCII
    /// (e.g. KELVIN SIGN to "k").
    static func handle(_ u: LeafBytes, _ start: Int, _ end: Int) -> LeafVerdict {
        let n = end - start
        if n == 0 || n > 253 { return .invalid }
        var labelStart = start
        var labels = 0
        var i = start
        while true {
            if i == end || u[i] == 0x2E {
                let length = i - labelStart
                guard length >= 1, length <= 63, u[labelStart] != 0x2D, u[i - 1] != 0x2D else {
                    return .invalid
                }
                labels += 1
                if i == end {
                    // TLD: must start with a letter.
                    return labels >= 2 && leafIsAlpha(u[labelStart]) ? .valid : .invalid
                }
                labelStart = i + 1
            } else {
                let b = u[i]
                guard leafIsAlnum(b) || b == 0x2D else { return .invalid }
            }
            i += 1
        }
    }

    // MARK: NSID
    // ^([a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))+\.[a-zA-Z][a-zA-Z0-9]{0,62}$

    static func nsid(_ u: LeafBytes, _ start: Int, _ end: Int) -> LeafVerdict {
        let n = end - start
        if n == 0 || n > 317 { return .invalid }
        if leafIsLineTerminator(u[end - 1]) { return .undecided }
        var segmentStart = start
        var closedSegments = 0
        var i = start
        while i < end {
            if u[i] == 0x2E {
                // Non-final segment: 1...63 bytes of [A-Za-z0-9-], alphanumeric ends; the
                // first segment must start with a letter.
                let length = i - segmentStart
                guard length >= 1, length <= 63 else { return .invalid }
                let first = u[segmentStart]
                if closedSegments == 0 {
                    guard leafIsAlpha(first) else { return .invalid }
                } else {
                    guard leafIsAlnum(first) else { return .invalid }
                }
                guard leafIsAlnum(u[i - 1]) else { return .invalid }
                var j = segmentStart
                while j < i {
                    let b = u[j]
                    guard leafIsAlnum(b) || b == 0x2D else { return .invalid }
                    j += 1
                }
                closedSegments += 1
                segmentStart = i + 1
            }
            i += 1
        }
        // At least three segments in total.
        guard closedSegments >= 2 else { return .invalid }
        // Final segment: [a-zA-Z][a-zA-Z0-9]{0,62}
        let length = end - segmentStart
        guard length >= 1, length <= 63, leafIsAlpha(u[segmentStart]) else { return .invalid }
        var j = segmentStart + 1
        while j < end {
            guard leafIsAlnum(u[j]) else { return .invalid }
            j += 1
        }
        return .valid
    }

    // MARK: RecordKey  ^[a-zA-Z0-9._:~-]+$   (1...512 bytes, not "." or "..")

    static func recordKey(_ u: LeafBytes, _ start: Int, _ end: Int) -> LeafVerdict {
        let n = end - start
        if n == 0 || n > 512 { return .invalid }
        if n == 1, u[start] == 0x2E { return .invalid }
        if n == 2, u[start] == 0x2E, u[start + 1] == 0x2E { return .invalid }
        if leafIsLineTerminator(u[end - 1]) { return .undecided }
        var i = start
        while i < end {
            let b = u[i]
            guard leafIsAlnum(b) || b == 0x2E || b == 0x5F || b == 0x3A || b == 0x7E || b == 0x2D else {
                return .invalid
            }
            i += 1
        }
        return .valid
    }

    /// Whether any byte in `u[start..<end]` is an ASCII uppercase letter.
    static func containsUppercase(_ u: LeafBytes, _ start: Int, _ end: Int) -> Bool {
        var i = start
        while i < end {
            if leafIsUpper(u[i]) { return true }
            i += 1
        }
        return false
    }

    // MARK: String-level verdicts

    static func didVerdict(_ s: String) -> LeafVerdict {
        withBytes(s) { u in did(u, 0, u.count) }
    }

    static func handleVerdict(_ s: String) -> LeafVerdict {
        withBytes(s) { u in handle(u, 0, u.count) }
    }

    static func nsidVerdict(_ s: String) -> LeafVerdict {
        withBytes(s) { u in nsid(u, 0, u.count) }
    }

    static func recordKeyVerdict(_ s: String) -> LeafVerdict {
        withBytes(s) { u in recordKey(u, 0, u.count) }
    }

    // MARK: Public AT-URI grammar

    /// The fields of a public (non-space) AT-URI accepted by the fast path.
    struct PublicATURI {
        let authority: String
        let collection: String?
        let recordKey: String?
        let authorityIsDID: Bool
    }

    /// Single-pass parse of `at://{authority}[/{collection}[/{rkey}]]`.
    ///
    /// Returns `nil` whenever the legacy parser must decide (and then also produce the
    /// legacy error text verbatim): non-`at://`, over-long, empty authority, a third
    /// `/` (more segments or a space URI), a `space` first segment, an authority
    /// that is neither a DID nor a handle, and any `.undecided` validator verdict.
    ///
    /// Accepted input is pure ASCII without CR or LF (every validated component is),
    /// so the legacy Character-based `hasPrefix`, `count`, `dropFirst` and `split`
    /// coincide with these byte operations.
    static func parsePublicATURI(_ s: String) -> PublicATURI? {
        withUTF8(s) { buffer -> PublicATURI? in
            #if compiler(>=6.2)
                let u = unsafe LeafBytes(_unsafeElements: buffer)
            #else
                let u = buffer
            #endif
            let n = u.count
            guard n > 5, n <= 8192,
                  u[0] == 0x61, u[1] == 0x74, u[2] == 0x3A, u[3] == 0x2F, u[4] == 0x2F
            else { return nil }

            var slash1 = -1
            var slash2 = -1
            var i = 5
            while i < n {
                if u[i] == 0x2F {
                    if slash1 < 0 {
                        slash1 = i
                    } else if slash2 < 0 {
                        slash2 = i
                    } else {
                        return nil
                    }
                }
                i += 1
            }

            let authorityEnd = slash1 < 0 ? n : slash1
            guard authorityEnd > 5 else { return nil }

            let authorityIsDID: Bool
            switch did(u, 5, authorityEnd) {
            case .valid:
                authorityIsDID = true
            case .undecided:
                return nil
            case .invalid:
                guard handle(u, 5, authorityEnd) == .valid else { return nil }
                authorityIsDID = false
            }

            var collection: String?
            var recordKeyValue: String?
            if slash1 >= 0 {
                let collectionStart = slash1 + 1
                let collectionEnd = slash2 < 0 ? n : slash2
                if collectionEnd - collectionStart == 5,
                   u[collectionStart] == 0x73, u[collectionStart + 1] == 0x70,
                   u[collectionStart + 2] == 0x61, u[collectionStart + 3] == 0x63,
                   u[collectionStart + 4] == 0x65
                {
                    // "space": the permissioned-data grammar, handled by the legacy parser.
                    return nil
                }
                if collectionEnd > collectionStart {
                    guard nsid(u, collectionStart, collectionEnd) == .valid else { return nil }
                    collection = internedCollection(u, buffer, collectionStart, collectionEnd)
                }
                if slash2 >= 0 {
                    let keyStart = slash2 + 1
                    if n > keyStart {
                        guard recordKey(u, keyStart, n) == .valid else { return nil }
                        recordKeyValue = string(buffer, keyStart, n)
                    }
                }
            }

            return PublicATURI(
                authority: string(buffer, 5, authorityEnd),
                collection: collection,
                recordKey: recordKeyValue,
                authorityIsDID: authorityIsDID
            )
        }
    }

    @inline(__always)
    static func string(_ buffer: UnsafeBufferPointer<UInt8>, _ start: Int, _ end: Int) -> String {
        String(decoding: UnsafeBufferPointer(rebasing: buffer[start ..< end]), as: UTF8.self)
    }

    // MARK: Collection interning

    /// Returns an immortal string literal for the most common record collections
    /// (no allocation, no lock), or a fresh string otherwise. String identity is not
    /// observable, so this is value-identical to `String(decoding:as:)`.
    @inline(__always)
    static func internedCollection(
        _ u: LeafBytes, _ buffer: UnsafeBufferPointer<UInt8>, _ start: Int, _ end: Int
    ) -> String {
        // Every literal below is ASCII; `matches` also checks the length, so a case
        // label can never select a literal of a different length.
        switch end - start {
        case 18:
            if matches(u, start, end, "app.bsky.feed.post") { return "app.bsky.feed.post" }
            if matches(u, start, end, "app.bsky.feed.like") { return "app.bsky.feed.like" }
        case 19:
            if matches(u, start, end, "app.bsky.graph.list") { return "app.bsky.graph.list" }
        case 20:
            if matches(u, start, end, "app.bsky.feed.repost") { return "app.bsky.feed.repost" }
            if matches(u, start, end, "app.bsky.graph.block") { return "app.bsky.graph.block" }
        case 21:
            if matches(u, start, end, "app.bsky.graph.follow") { return "app.bsky.graph.follow" }
        case 22:
            if matches(u, start, end, "app.bsky.actor.profile") { return "app.bsky.actor.profile" }
            if matches(u, start, end, "app.bsky.feed.postgate") { return "app.bsky.feed.postgate" }
        case 23:
            if matches(u, start, end, "app.bsky.feed.generator") { return "app.bsky.feed.generator" }
            if matches(u, start, end, "app.bsky.graph.listitem") { return "app.bsky.graph.listitem" }
        case 24:
            if matches(u, start, end, "app.bsky.feed.threadgate") { return "app.bsky.feed.threadgate" }
            if matches(u, start, end, "app.bsky.graph.listblock") { return "app.bsky.graph.listblock" }
            if matches(u, start, end, "app.bsky.labeler.service") { return "app.bsky.labeler.service" }
        case 26:
            if matches(u, start, end, "app.bsky.graph.starterpack") { return "app.bsky.graph.starterpack" }
        case 27:
            if matches(u, start, end, "app.bsky.graph.verification") { return "app.bsky.graph.verification" }
        default:
            break
        }
        return string(buffer, start, end)
    }

    /// Byte equality of `u[start..<end]` with an ASCII literal.
    @inline(__always)
    static func matches(_ u: LeafBytes, _ start: Int, _ end: Int, _ literal: StaticString) -> Bool {
        let count = literal.utf8CodeUnitCount
        guard end - start == count else { return false }
        let pointer = literal.utf8Start
        var i = 0
        while i < count {
            if u[start + i] != pointer[i] { return false }
            i += 1
        }
        return true
    }
}

// MARK: - SPI for equivalence harnesses

/// Read-only probes into the fast-path decisions, for equivalence and coverage
/// harnesses. These are pure functions over the production scanners; they add no
/// state or counters to the decode path.
@_spi(LeafScanners)
public enum LeafScannerProbe {
    public static func didVerdict(_ s: String) -> LeafVerdict { LeafScan.didVerdict(s) }
    public static func handleVerdict(_ s: String) -> LeafVerdict { LeafScan.handleVerdict(s) }
    public static func nsidVerdict(_ s: String) -> LeafVerdict { LeafScan.nsidVerdict(s) }
    public static func recordKeyVerdict(_ s: String) -> LeafVerdict { LeafScan.recordKeyVerdict(s) }

    /// Whether `ATProtocolURI(uriString:)` answers this input on the fast path.
    public static func atURIUsesFastPath(_ s: String) -> Bool { LeafScan.parsePublicATURI(s) != nil }

    /// Whether `ATProtocolDate` parses this input on the byte fast path.
    public static func dateUsesFastPath(_ s: String) -> Bool { ATProtocolDate.fastParse(s) != nil }
}
