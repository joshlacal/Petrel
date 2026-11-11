//
//  RichText.swift
//
//
//  Created by Josh LaCalamito on 11/30/23.
//

import Foundation

#if canImport(SwiftUI)
    import SwiftUI

    public extension AppBskyFeedPost {
        /// The post text as an `AttributedString` with its facets applied.
        ///
        /// Links get a `link` attribute. Mentions and tags get the accent
        /// colour, a `mention://<did>` or `tag://<tag>` link, and the
        /// ``AttributeScopes/RichTextAttributes/mentionLink`` or
        /// ``AttributeScopes/RichTextAttributes/tagLink`` attribute holding the
        /// exact DID or tag. Read those attributes rather than parsing the
        /// link: a tag that cannot be written as a URL host (non-ASCII text,
        /// spaces, `%`) is linked as `tag:///<percent-encoded tag>` instead.
        ///
        /// Facets come from the network and are not trusted: negative,
        /// out-of-range or inverted byte offsets are skipped, and offsets that
        /// fall inside a character are widened to the whole character.
        var facetsAsAttributedString: AttributedString {
            var attributedString = AttributedString(text)
            let richText = RichText(post: self)
            guard !richText.facets.isEmpty, !text.isEmpty else { return attributedString }
            let boundaries = CharacterBoundaryMap(text)

            for facet in richText.facets {
                guard let start = boundaries.index(atOrBeforeUTF8Offset: facet.index.byteStart),
                      let end = boundaries.index(atOrAfterUTF8Offset: facet.index.byteEnd),
                      start < end,
                      let attrStart = AttributedString.Index(start, within: attributedString),
                      let attrEnd = AttributedString.Index(end, within: attributedString)
                else {
                    continue
                }
                let range = attrStart ..< attrEnd

                for feature in facet.features {
                    switch feature {
                    case let .appBskyRichtextFacetLink(linkFeature):
                        if let url = URL(string: linkFeature.uri.uriString()) {
                            attributedString[range].link = url
                        }
                    case let .appBskyRichtextFacetMention(mentionFeature):
                        attributedString[range].foregroundColor = .accentColor
                        let encodedDID =
                            mentionFeature.did.didString().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                                ?? mentionFeature.did.didString()
                        if let url = URL(string: "mention://" + encodedDID) {
                            attributedString[range].link = url
                        }
                        attributedString[range].richText.mentionLink = mentionFeature.did.didString()
                    case let .appBskyRichtextFacetTag(tagFeature):
                        attributedString[range].foregroundColor = .accentColor
                        if let url = RichTextLinkURL.tagURL(tagFeature.tag) {
                            attributedString[range].link = url
                        }
                        attributedString[range].richText.tagLink = tagFeature.tag
                    case let .unexpected(unexpected):
                        // A feature this SDK does not know: leave the text plain.
                        LogManager.logDebug("RichText - Unexpected facet feature: \(unexpected.textRepresentation)")
                    }
                }
            }

            return attributedString
        }
    }
#endif

public extension String {
    /// The index at a UTF-8 byte offset, or `nil` when the offset is negative,
    /// past the end, or not on a character boundary.
    func index(atUTF8Offset offset: Int) -> String.Index? {
        guard offset >= 0,
              let utf8Index = utf8.index(utf8.startIndex, offsetBy: offset, limitedBy: utf8.endIndex)
        else {
            return nil
        }
        return utf8Index.samePosition(in: self)
    }
}

/// Maps UTF-8 byte offsets to character boundaries, widening offsets that
/// fall inside a character outward.
struct CharacterBoundaryMap {
    /// The UTF-8 offset of every character boundary, ascending, including the end.
    private let offsets: [Int]
    private let indices: [String.Index]

    init(_ text: String) {
        var offsets: [Int] = []
        var indices: [String.Index] = []
        var offset = 0
        var index = text.startIndex
        while index < text.endIndex {
            offsets.append(offset)
            indices.append(index)
            let next = text.index(after: index)
            offset += text.utf8.distance(from: index, to: next)
            index = next
        }
        offsets.append(offset)
        indices.append(text.endIndex)
        self.offsets = offsets
        self.indices = indices
    }

    /// The last boundary at or before `offset`; `nil` when `offset` is outside the text.
    func index(atOrBeforeUTF8Offset offset: Int) -> String.Index? {
        guard let last = offsets.last, offset >= 0, offset <= last else { return nil }
        // First position whose offset is greater than `offset`, minus one.
        var low = 0
        var high = offsets.count
        while low < high {
            let mid = (low + high) / 2
            if offsets[mid] <= offset {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return indices[low - 1]
    }

    /// The first boundary at or after `offset`; `nil` when `offset` is outside the text.
    func index(atOrAfterUTF8Offset offset: Int) -> String.Index? {
        guard let last = offsets.last, offset >= 0, offset <= last else { return nil }
        var low = 0
        var high = offsets.count
        while low < high {
            let mid = (low + high) / 2
            if offsets[mid] < offset {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return indices[low]
    }
}

/// The custom URL forms used to carry mentions and tags in a `link` attribute.
enum RichTextLinkURL {
    private static let tagPathAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/%")
        return set
    }()

    /// `tag://<tag>` when the tag survives being a URL host verbatim, otherwise
    /// `tag:///<percent-encoded tag>`. Foundation IDNA-encodes hosts, so a tag
    /// such as `日本語` would otherwise come back as `xn--wgv71a119e`.
    static func tagURL(_ tag: String) -> URL? {
        let direct = "tag://" + tag
        if !tag.hasPrefix("/"), let url = URL(string: direct), url.absoluteString == direct {
            return url
        }
        guard let encoded = tag.addingPercentEncoding(withAllowedCharacters: tagPathAllowed) else {
            return nil
        }
        return URL(string: "tag:///" + encoded)
    }

    /// Recovers the tag from either URL form.
    static func tag(from urlString: String) -> String? {
        if urlString.hasPrefix("tag:///") {
            let encoded = String(urlString.dropFirst("tag:///".count))
            return encoded.removingPercentEncoding ?? encoded
        }
        if urlString.hasPrefix("tag://") {
            return String(urlString.dropFirst("tag://".count))
        }
        return nil
    }
}

#if canImport(SwiftUI)
    /// Attribute carrying the exact tag of a hashtag run.
    public struct TagLink: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = String
        public static let name: String = "tagLink"
    }

    /// Attribute carrying the exact DID of a mention run.
    public struct MentionLink: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = String
        public static let name: String = "mentionLink"
    }

    public extension AttributeScopes {
        /// Attributes Petrel adds to rich text runs.
        struct RichTextAttributes: AttributeScope {
            /// The exact tag of a hashtag run.
            public let tagLink: TagLink
            /// The exact DID of a mention run.
            public let mentionLink: MentionLink
        }

        /// Attributes Petrel adds to rich text runs.
        var richText: RichTextAttributes.Type {
            RichTextAttributes.self
        }
    }
#endif

// MARK: AttributedString to facets

public extension AttributedString {
    /// Converts link, mention and tag runs back into facets with UTF-8 byte offsets.
    ///
    /// Mentions and tags are read from the ``AttributeScopes/RichTextAttributes``
    /// attributes when present, so the values written by
    /// ``AppBskyFeedPost/facetsAsAttributedString`` round-trip exactly; otherwise
    /// they are recovered from `mention://` and `tag://` links. Any other link
    /// becomes a link facet. Adjacent runs with the same target are merged.
    ///
    /// - Returns: The facets, or `nil` when the string has none.
    /// - Throws: When a mention does not hold a valid DID.
    func toFacets() throws -> [AppBskyRichtextFacet]? {
        let fullString = String(characters[...])

        enum Target: Equatable {
            case mention(String)
            case tag(String)
            case link(String)
        }

        var rawRuns: [(byteStart: Int, byteEnd: Int, target: Target)] = []

        for run in runs {
            let range = run.range
            guard
                let lowerBound = String.Index(range.lowerBound, within: fullString),
                let upperBound = String.Index(range.upperBound, within: fullString),
                lowerBound < upperBound
            else {
                continue
            }

            var target: Target?
            #if canImport(SwiftUI)
                if let did = run[MentionLink.self] {
                    target = .mention(did)
                } else if let tag = run[TagLink.self] {
                    target = .tag(tag)
                }
            #endif
            if target == nil, let url = run.link {
                let urlString = url.absoluteString
                if urlString.hasPrefix("mention://") {
                    let encodedDID = String(urlString.dropFirst("mention://".count))
                    target = .mention(encodedDID.removingPercentEncoding ?? encodedDID)
                } else if let tag = RichTextLinkURL.tag(from: urlString) {
                    target = .tag(tag)
                } else {
                    target = .link(urlString)
                }
            }
            guard let target else { continue }

            let byteStart = fullString[..<lowerBound].utf8.count
            let byteEnd = byteStart + fullString[lowerBound ..< upperBound].utf8.count
            rawRuns.append((byteStart, byteEnd, target))
        }

        rawRuns.sort { $0.byteStart < $1.byteStart }

        // Merge adjacent runs with the same target to avoid fragmented facets.
        var mergedRuns: [(byteStart: Int, byteEnd: Int, target: Target)] = []
        for run in rawRuns {
            if let last = mergedRuns.last, last.target == run.target, last.byteEnd == run.byteStart {
                mergedRuns[mergedRuns.count - 1].byteEnd = run.byteEnd
            } else {
                mergedRuns.append(run)
            }
        }

        var facets: [AppBskyRichtextFacet] = []
        for run in mergedRuns {
            let feature: AppBskyRichtextFacet.AppBskyRichtextFacetFeaturesUnion
            switch run.target {
            case let .mention(did):
                feature = try .appBskyRichtextFacetMention(AppBskyRichtextFacet.Mention(did: DID(didString: did)))
            case let .tag(tag):
                feature = .appBskyRichtextFacetTag(AppBskyRichtextFacet.Tag(tag: tag))
            case let .link(urlString):
                feature = .appBskyRichtextFacetLink(AppBskyRichtextFacet.Link(uri: URI(uriString: urlString)))
            }
            facets.append(AppBskyRichtextFacet(
                index: AppBskyRichtextFacet.ByteSlice(byteStart: run.byteStart, byteEnd: run.byteEnd),
                features: [feature]
            ))
        }

        return facets.isEmpty ? nil : facets
    }
}
