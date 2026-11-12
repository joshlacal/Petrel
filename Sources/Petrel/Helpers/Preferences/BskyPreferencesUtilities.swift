import Foundation

/// Pure helpers shared by the preference setters. Ports of
/// `packages/api/src/util.ts` in the reference implementation.
enum BskyPreferencesUtilities {
    /// The characters `String.prototype.trim()` removes: ECMAScript WhiteSpace
    /// plus LineTerminator. Spelled out because Foundation's whitespace sets
    /// differ (they omit U+FEFF and include U+0085).
    static func isJavaScriptTrimmable(_ scalar: Unicode.Scalar) -> Bool {
        JSText.isWhitespace(scalar)
    }

    /// `\r`, `\n`, soft hyphen, word joiner, zero-width joiner, zero-width
    /// non-joiner and zero-width space: characters that cannot be part of a muted word.
    private static func isDisallowedInMutedWord(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0D, 0x0A, 0xAD, 0x2060, 0x200D, 0x200C, 0x200B:
            return true
        default:
            return false
        }
    }

    /// Normalizes a muted word before it is stored.
    ///
    /// Trims surrounding whitespace, drops one leading `#` (unless it is the
    /// start of the keycap emoji `#️⃣`), and removes the first run of line
    /// breaks and invisible joiners. The result may be empty, in which case
    /// the word must not be stored.
    static func sanitizeMutedWordValue(_ value: String) -> String {
        var scalars = Array(value.unicodeScalars)
        while let first = scalars.first, isJavaScriptTrimmable(first) {
            scalars.removeFirst()
        }
        while let last = scalars.last, isJavaScriptTrimmable(last) {
            scalars.removeLast()
        }

        // /^#(?!️)/
        if scalars.first == "#", scalars.count < 2 || scalars[1].value != 0xFE0F {
            scalars.removeFirst()
        }

        // /[\r\n­⁠‍‌​]+/ without the global flag: first run only.
        if let start = scalars.firstIndex(where: isDisallowedInMutedWord) {
            var end = start
            while end < scalars.count, isDisallowedInMutedWord(scalars[end]) {
                end += 1
            }
            scalars.removeSubrange(start ..< end)
        }

        var result = String.UnicodeScalarView()
        result.append(contentsOf: scalars)
        return String(result)
    }

    /// Splits second-generation saved feeds into the two URI arrays of the
    /// first-generation preference. Pinned feeds are also saved.
    static func savedFeedsToURIArrays(
        _ savedFeeds: [(value: String, pinned: Bool)]
    ) -> (pinned: [String], saved: [String]) {
        var pinned: [String] = []
        var saved: [String] = []
        for feed in savedFeeds {
            if feed.pinned {
                pinned.append(feed.value)
            }
            saved.append(feed.value)
        }
        return (pinned, saved)
    }

    /// The saved-feed type an AT URI stands for: `feed`, `list`, or `unknown`.
    ///
    /// - Throws: ``BskyAgentError/invalidInput(_:)`` when `uri` is not an AT URI.
    static func savedFeedType(of uri: String) throws -> String {
        let parsed: ATProtocolURI
        do {
            parsed = try ATProtocolURI(uriString: uri)
        } catch {
            throw BskyAgentError.invalidInput("Saved feed value is not an AT URI: \(uri)")
        }
        switch parsed.collection {
        case "app.bsky.feed.generator":
            return "feed"
        case "app.bsky.graph.list":
            return "list"
        default:
            return "unknown"
        }
    }

    /// Checks a saved feed before it is written.
    ///
    /// - Throws: ``BskyAgentError/invalidInput(_:)`` when the identifier is
    ///   empty, or when a `feed`/`list` entry does not point at a record of
    ///   the matching collection.
    static func validateSavedFeed(id: String, type: String, value: String) throws {
        guard !id.isEmpty else {
            throw BskyAgentError.invalidInput("Saved feed must have an `id` - use a TID")
        }
        guard type == "feed" || type == "list" else {
            return
        }
        let actual = try savedFeedType(of: value)
        if type == "feed", actual != "feed" {
            throw BskyAgentError.invalidInput("Saved feed of type 'feed' must be a feed, got \(value)")
        }
        if type == "list", actual != "list" {
            throw BskyAgentError.invalidInput("Saved feed of type 'list' must be a list, got \(value)")
        }
    }

    /// Checks a saved feed before it is written.
    static func validateSavedFeed(_ savedFeed: AppBskyActorDefs.SavedFeed) throws {
        try validateSavedFeed(id: savedFeed.id, type: savedFeed.type, value: savedFeed.value)
    }
}
