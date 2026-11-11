import Foundation

/// Something rich text detection found in plain text: a mention, a link or a tag,
/// with its position as UTF-8 byte offsets.
///
/// Mentions carry the handle as written. A mention only becomes a facet once
/// the handle has been resolved to a DID, because `app.bsky.richtext.facet#mention`
/// stores a DID.
public struct RichTextDetection: Sendable, Hashable {
    /// What was detected.
    public enum Kind: Sendable, Hashable {
        /// An `@handle` mention. The value is the handle without the `@`.
        case mention(handle: String)
        /// A link. The value is the URI to link to, with `https://` added when
        /// the text only had a bare domain.
        case link(uri: String)
        /// A hashtag (value without the `#`) or a cashtag (value with its `$`, uppercased).
        case tag(String)
    }

    /// Offset of the first byte of the annotated text, in UTF-8 bytes.
    public let byteStart: Int
    /// Offset one past the last byte of the annotated text, in UTF-8 bytes.
    public let byteEnd: Int
    /// What was detected.
    public let kind: Kind

    /// Creates a detection.
    public init(byteStart: Int, byteEnd: Int, kind: Kind) {
        self.byteStart = byteStart
        self.byteEnd = byteEnd
        self.kind = kind
    }
}

/// Port of `@atproto/api`'s `detectFacets`.
///
/// The regular expressions are the reference ones, rewritten for ICU where
/// ECMAScript and ICU disagree: `\s` and `\S` are spelled out as the
/// ECMAScript whitespace set, `\d` as `0-9`, `\b` as an ASCII word boundary,
/// and `^`/`$` as absolute anchors. Matching runs over UTF-16, like JavaScript,
/// and offsets are converted to UTF-8 bytes afterwards.
enum RichTextDetector {
    private static let ws = JSText.whitespaceClass
    private static let asciiWordBoundary =
        "(?:(?<=[A-Za-z0-9_])(?![A-Za-z0-9_])|(?<![A-Za-z0-9_])(?=[A-Za-z0-9_]))"
    private static let tagExcluded = #"­⁠ ​‌‍⃢"#

    /// `/(^|\s|\()(@)([a-zA-Z0-9.-]+)(\b)/g`
    private static let mentionRegex = compile(
        #"(\A|[\#(ws)]|\()(@)([a-zA-Z0-9.-]+)"# + asciiWordBoundary
    )

    /// `/(^|\s|\()((https?:\/\/[\S]+)|((?<domain>[a-z][a-z0-9]*(\.[a-z0-9]+)+)[\S]*))/gim`
    ///
    /// Group 2 is the whole link text, group 5 the bare domain.
    private static let urlRegex = compile(
        #"(\A|[\#(ws)]|\()(([hH][tT][tT][pP][sS]?://[^\#(ws)]+)|(([A-Za-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)+)[^\#(ws)]*))"#
    )

    /// `/(^|\s)[#＃]((?!️)[^\s…]*[^\d\s\p{P}…]+[^\s…]*)?/gu`
    private static let tagRegex = compile(
        #"(\A|[\#(ws)])[#＃]((?!️)[^\#(ws)\#(tagExcluded)]*[^0-9\#(ws)\p{P}\#(tagExcluded)]+[^\#(ws)\#(tagExcluded)]*)?"#
    )

    /// `/(^|\s|\()\$([A-Za-z][A-Za-z0-9]{0,4})(?=\s|$|[.,;:!?)"'’])/gu`
    private static let cashtagRegex = compile(
        #"(\A|[\#(ws)]|\()\$([A-Za-z][A-Za-z0-9]{0,4})(?=[\#(ws)]|\z|[.,;:!?)"'’])"#
    )

    /// `/\p{P}+$/gu`
    private static let trailingPunctuationRegex = compile(#"\p{P}+\z"#)

    private static func compile(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            // The patterns are compile-time constants covered by tests.
            preconditionFailure("Invalid rich text pattern: \(pattern)")
        }
    }

    static func detect(_ text: String) -> [RichTextDetection] {
        guard !text.isEmpty else { return [] }
        let utf16 = NSString(string: text)
        let offsets = UTF16ToUTF8Offsets(text)
        let whole = NSRange(location: 0, length: utf16.length)
        var detections: [RichTextDetection] = []

        // Mentions.
        for match in mentionRegex.matches(in: text, options: [], range: whole) {
            let handleRange = match.range(at: 3)
            let handle = utf16.substring(with: handleRange)
            guard TopLevelDomains.isValidDomain(handle) || handle.hasSuffix(".test") else {
                continue // probably not a handle
            }
            let start = handleRange.location - 1
            detections.append(RichTextDetection(
                byteStart: offsets.utf8Offset(atUTF16: start),
                byteEnd: offsets.utf8Offset(atUTF16: handleRange.location + handleRange.length),
                kind: .mention(handle: handle)
            ))
        }

        // Links.
        for match in urlRegex.matches(in: text, options: [], range: whole) {
            let linkRange = match.range(at: 2)
            var uri = utf16.substring(with: linkRange)
            if !uri.utf8.starts(with: "http".utf8) {
                let domainRange = match.range(at: 5)
                guard domainRange.location != NSNotFound,
                      TopLevelDomains.isValidDomain(utf16.substring(with: domainRange))
                else {
                    continue
                }
                uri = "https://" + uri
            }
            var end = linkRange.location + linkRange.length
            // Strip one trailing punctuation mark, then an unbalanced closing parenthesis.
            if let last = uri.unicodeScalars.last, ".,;:!?".unicodeScalars.contains(last) {
                uri.unicodeScalars.removeLast()
                end -= 1
            }
            if uri.unicodeScalars.last == ")", !uri.unicodeScalars.contains("(") {
                uri.unicodeScalars.removeLast()
                end -= 1
            }
            detections.append(RichTextDetection(
                byteStart: offsets.utf8Offset(atUTF16: linkRange.location),
                byteEnd: offsets.utf8Offset(atUTF16: end),
                kind: .link(uri: uri)
            ))
        }

        // Hashtags.
        for match in tagRegex.matches(in: text, options: [], range: whole) {
            let tagRange = match.range(at: 2)
            guard tagRange.location != NSNotFound, tagRange.length > 0 else { continue }
            let raw = utf16.substring(with: tagRange)
            // Strip trailing punctuation. (The reference also trims whitespace,
            // which the pattern can never capture.)
            let tag = trailingPunctuationRegex.stringByReplacingMatches(
                in: raw,
                options: [],
                range: NSRange(location: 0, length: NSString(string: raw).length),
                withTemplate: ""
            )
            guard !tag.isEmpty, tag.count <= 64 else { continue }

            let index = match.range.location + match.range(at: 1).length
            detections.append(RichTextDetection(
                byteStart: offsets.utf8Offset(atUTF16: index),
                byteEnd: offsets.utf8Offset(atUTF16: index + 1 + NSString(string: tag).length),
                kind: .tag(tag)
            ))
        }

        // Cashtags.
        for match in cashtagRegex.matches(in: text, options: [], range: whole) {
            let tickerRange = match.range(at: 2)
            guard tickerRange.location != NSNotFound, tickerRange.length > 0 else { continue }
            let ticker = utf16.substring(with: tickerRange).uppercased()
            let index = match.range.location + match.range(at: 1).length
            detections.append(RichTextDetection(
                byteStart: offsets.utf8Offset(atUTF16: index),
                byteEnd: offsets.utf8Offset(atUTF16: index + 1 + tickerRange.length),
                kind: .tag("$" + ticker)
            ))
        }

        return detections
    }
}

/// Converts UTF-16 code unit offsets (what the regular expression engine
/// reports) into UTF-8 byte offsets (what facets use).
struct UTF16ToUTF8Offsets {
    /// `table[i]` is the UTF-8 offset of UTF-16 offset `i`; one extra entry for the end.
    private let table: [Int]

    init(_ text: String) {
        var table: [Int] = []
        table.reserveCapacity(text.utf16.count + 1)
        var utf8 = 0
        for scalar in text.unicodeScalars {
            let units = UTF16.width(scalar)
            for _ in 0 ..< units {
                // An offset inside a surrogate pair maps to the start of the scalar.
                table.append(utf8)
            }
            utf8 += UTF8.width(scalar)
        }
        table.append(utf8)
        self.table = table
    }

    func utf8Offset(atUTF16 offset: Int) -> Int {
        table[min(max(offset, 0), table.count - 1)]
    }
}
