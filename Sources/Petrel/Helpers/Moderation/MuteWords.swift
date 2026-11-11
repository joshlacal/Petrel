import Foundation

public extension Moderation {
    /// Finds the muted words that match a piece of text.
    ///
    /// Matching follows the official client:
    /// - A muted word that equals one of the tags (outline tags or tag facets)
    ///   always matches, whatever its targets.
    /// - Otherwise only words targeting `content` are considered. They match
    ///   whole words, case-insensitively, ignoring leading and trailing
    ///   punctuation; punctuation inside a word may be treated as a space or
    ///   removed (`super-bad` matches `super bad`, `superbad`, `super`, `bad`).
    /// - Single-character words, phrases containing spaces or punctuation, and
    ///   every word when the first language is one written without spaces
    ///   (Japanese, Chinese, Korean, Thai, Vietnamese) match as substrings.
    /// - Expired words are skipped, as are words limited to accounts the
    ///   viewer does not follow when the viewer follows `actor`.
    ///
    /// - Parameters:
    ///   - mutedWords: The viewer's muted words.
    ///   - text: The text to test.
    ///   - facets: Rich text facets of the text; their tags are tested too.
    ///   - outlineTags: Tags attached to the post outside its text.
    ///   - languages: Language tags of the text. Only the first is consulted.
    ///   - actor: The author of the text.
    ///   - now: The time used to decide whether a muted word has expired.
    /// - Returns: One match per muted word that matched, in the order of
    ///   `mutedWords`. Empty when nothing matched.
    static func matchMuteWords(
        mutedWords: [AppBskyActorDefs.MutedWord],
        text: String,
        facets: [AppBskyRichtextFacet]? = nil,
        outlineTags: [String]? = nil,
        languages: [String]? = nil,
        actor: (any ModerationSubjectProfile)? = nil,
        now: Date = Date()
    ) -> [MuteWordMatch] {
        let exception = MuteWordMatcher.languageExceptions.contains(languages?.first ?? "")

        var tags: [[Unicode.Scalar]] = []
        for tag in outlineTags ?? [] {
            tags.append(Array(tag.lowercased().unicodeScalars))
        }
        for facet in facets ?? [] {
            for feature in facet.features {
                if case let .appBskyRichtextFacetTag(tag) = feature {
                    tags.append(Array(tag.tag.lowercased().unicodeScalars))
                }
            }
        }

        let postText = Array(text.lowercased().unicodeScalars)
        let postLength = MuteWordMatcher.utf16Length(postText)
        var postWords: [[Unicode.Scalar]]?

        var matches: [MuteWordMatch] = []

        for muteWord in mutedWords {
            let mutedWord = Array(muteWord.value.lowercased().unicodeScalars)
            let mutedLength = MuteWordMatcher.utf16Length(mutedWord)

            if let expiresAt = muteWord.expiresAt, expiresAt.date < now {
                continue
            }
            if muteWord.actorTarget == "exclude-following", actor?.viewer?.following != nil {
                continue
            }

            // `content` applies to tags as well
            if tags.contains(mutedWord) {
                matches.append(MuteWordMatch(word: muteWord, predicate: muteWord.value))
                continue
            }
            // the rest of the checks are for `content` only
            guard muteWord.targets.contains(where: { $0.rawValue == "content" }) else { continue }

            // single character or language exception: substring match
            if mutedLength == 1 || exception, MuteWordMatcher.contains(postText, mutedWord) {
                matches.append(MuteWordMatch(word: muteWord, predicate: muteWord.value))
                continue
            }
            // too long
            if mutedLength > postLength { continue }
            // exact match
            if mutedWord == postText {
                matches.append(MuteWordMatch(word: muteWord, predicate: muteWord.value))
                continue
            }
            // any muted phrase with space or punctuation
            if mutedWord.contains(where: { MuteWordMatcher.isWhitespace($0) || MuteWordMatcher.isPunctuation($0) }),
               MuteWordMatcher.contains(postText, mutedWord)
            {
                matches.append(MuteWordMatch(word: muteWord, predicate: muteWord.value))
                continue
            }

            // check individual character groups
            let words: [[Unicode.Scalar]]
            if let postWords {
                words = postWords
            } else {
                words = MuteWordMatcher.splitOnWhitespace(postText)
                postWords = words
            }
            if let predicate = MuteWordMatcher.matchingWord(in: words, mutedWord: mutedWord, mutedLength: mutedLength) {
                matches.append(MuteWordMatch(word: muteWord, predicate: predicate))
            }
        }

        return matches
    }

    /// Whether any muted word matches the text. See
    /// ``matchMuteWords(mutedWords:text:facets:outlineTags:languages:actor:now:)``.
    static func hasMutedWord(
        mutedWords: [AppBskyActorDefs.MutedWord],
        text: String,
        facets: [AppBskyRichtextFacet]? = nil,
        outlineTags: [String]? = nil,
        languages: [String]? = nil,
        actor: (any ModerationSubjectProfile)? = nil,
        now: Date = Date()
    ) -> Bool {
        !matchMuteWords(
            mutedWords: mutedWords,
            text: text,
            facets: facets,
            outlineTags: outlineTags,
            languages: languages,
            actor: actor,
            now: now
        ).isEmpty
    }
}

/// Scalar-level helpers for muted word matching.
///
/// The reference implementation is written against JavaScript strings and
/// regular expressions. Working on Unicode scalars reproduces its results for
/// every well-formed string without depending on a regex engine whose `\s`
/// and case rules differ from JavaScript's.
enum MuteWordMatcher {
    /// Language codes for languages that either don't use spaces, or don't use
    /// them in a way conducive to word-based filtering.
    static let languageExceptions: Set<String> = ["ja", "zh", "ko", "th", "vi"]

    /// JavaScript's `\s`: White_Space code points plus U+FEFF.
    static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        JSText.isWhitespace(scalar)
    }

    /// `\p{P}`: any punctuation general category.
    static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return true
        default:
            return false
        }
    }

    /// The length JavaScript reports for the string (UTF-16 code units).
    static func utf16Length(_ scalars: [Unicode.Scalar]) -> Int {
        scalars.reduce(0) { $0 + ($1.value > 0xFFFF ? 2 : 1) }
    }

    /// Substring test. An empty needle is contained in everything.
    static func contains(_ haystack: [Unicode.Scalar], _ needle: [Unicode.Scalar]) -> Bool {
        if needle.isEmpty { return true }
        guard haystack.count >= needle.count else { return false }
        let first = needle[0]
        var index = 0
        let last = haystack.count - needle.count
        while index <= last {
            if haystack[index] == first, haystack[index ..< index + needle.count].elementsEqual(needle) {
                return true
            }
            index += 1
        }
        return false
    }

    /// Splits on every single whitespace scalar (`split(/[\s\n\t\r\f\v]+?/g)`),
    /// so consecutive whitespace yields empty words, as in the reference.
    static func splitOnWhitespace(_ scalars: [Unicode.Scalar]) -> [[Unicode.Scalar]] {
        var words: [[Unicode.Scalar]] = []
        var current: [Unicode.Scalar] = []
        for scalar in scalars {
            if isWhitespace(scalar) {
                words.append(current)
                current = []
            } else {
                current.append(scalar)
            }
        }
        words.append(current)
        return words
    }

    /// Splits on runs of punctuation (`split(/\p{P}+/u)`).
    static func splitOnPunctuation(_ scalars: [Unicode.Scalar]) -> [[Unicode.Scalar]] {
        var parts: [[Unicode.Scalar]] = []
        var current: [Unicode.Scalar] = []
        var inPunctuation = false
        for scalar in scalars {
            if isPunctuation(scalar) {
                if !inPunctuation {
                    parts.append(current)
                    current = []
                    inPunctuation = true
                }
            } else {
                inPunctuation = false
                current.append(scalar)
            }
        }
        parts.append(current)
        return parts
    }

    /// Removes leading and trailing punctuation (`replace(/(?:^\p{P}+|\p{P}+$)/gu, '')`).
    static func trimmingPunctuation(_ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        var start = scalars.startIndex
        var end = scalars.endIndex
        while start < end, isPunctuation(scalars[start]) {
            start += 1
        }
        while end > start, isPunctuation(scalars[end - 1]) {
            end -= 1
        }
        return Array(scalars[start ..< end])
    }

    /// Replaces each run of punctuation with one space (`replace(/\p{P}+/gu, ' ')`).
    static func replacingPunctuationWithSpace(_ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        var result: [Unicode.Scalar] = []
        var inPunctuation = false
        for scalar in scalars {
            if isPunctuation(scalar) {
                if !inPunctuation {
                    result.append(" ")
                    inPunctuation = true
                }
            } else {
                inPunctuation = false
                result.append(scalar)
            }
        }
        return result
    }

    static func string(_ scalars: [Unicode.Scalar]) -> String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars)
        return String(view)
    }

    /// Runs the per-word checks. Returns the word that matched, or `nil`.
    static func matchingWord(
        in words: [[Unicode.Scalar]],
        mutedWord: [Unicode.Scalar],
        mutedLength: Int
    ) -> String? {
        for word in words {
            if word == mutedWord {
                return string(word)
            }

            // Compare the word without leading/trailing punctuation, but allow
            // internal punctuation (such as `s@ssy`).
            let trimmed = trimmingPunctuation(word)
            if mutedWord == trimmed {
                return string(word)
            }
            if mutedLength > utf16Length(trimmed) { continue }

            if trimmed.contains(where: isPunctuation) {
                // Exit case for punctuation within the predicate that we _do_
                // allow: `and/or` should not match `Andor`.
                if trimmed.contains("/") {
                    return nil
                }

                let spaced = replacingPunctuationWithSpace(trimmed)
                if spaced == mutedWord {
                    return string(word)
                }

                let contiguous = spaced.filter { !isWhitespace($0) }
                if contiguous == mutedWord {
                    return string(word)
                }

                for part in splitOnPunctuation(trimmed) where part == mutedWord {
                    return string(word)
                }
            }
        }
        return nil
    }
}
