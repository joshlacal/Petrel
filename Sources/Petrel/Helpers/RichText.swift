//
//  RichText.swift
//
//
//  Created by Josh LaCalamito on 11/30/23.
//

import Foundation
import SwiftUI

public extension AppBskyFeedPost {
    var facetsAsAttributedString: AttributedString {
        guard let facets = facets, !text.isEmpty else { return AttributedString(text) }
        var attributedString = AttributedString(text)

        for facet in facets.sorted(by: { $0.index.byteStart < $1.index.byteStart }) {
            guard let start = text.index(atUTF8Offset: facet.index.byteStart),
                  let end = text.index(atUTF8Offset: facet.index.byteEnd),
                  start < end
            else {
                continue
            }

            // Convert String.Index to AttributedString.Index
            let attrStart = AttributedString.Index(start, within: attributedString)
            let attrEnd = AttributedString.Index(end, within: attributedString)

            if let attrStart = attrStart, let attrEnd = attrEnd {
                let range = attrStart ..< attrEnd

                // Apply features
                for feature in facet.features {
                    switch feature {
                    case let .appBskyRichtextFacetLink(linkFeature):
                        if let url = URL(string: linkFeature.uri.uriString()) {
                            attributedString[range].link = url
                        }
                    case let .appBskyRichtextFacetMention(mentionFeature):
                        attributedString[range].foregroundColor = .accentColor
                        let encodedDID =
                            mentionFeature.did.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                                ?? mentionFeature.did
                        let atURIString = "mention://" + encodedDID
                        if let url = URL(string: atURIString) {
                            attributedString[range].link = url
                        }
                        attributedString[range].richText.mentionLink = mentionFeature.did
                    case let .appBskyRichtextFacetTag(tagFeature):
                        attributedString[range].foregroundColor = .accentColor
                        let atURIString = "tag://" + tagFeature.tag
                        if let url = URL(string: atURIString) {
                            attributedString[range].link = url
                        }
                        attributedString[range].richText.tagLink = tagFeature.tag
                    case let .unexpected(unexpected):
                        print("Unexpected facet getting a red color: \(unexpected.textRepresentation)")
                        attributedString[range].foregroundColor = .red
                    }
                }
            }
        }

        return attributedString
    }
}

public extension String {
    func index(atUTF8Offset offset: Int) -> String.Index? {
        guard let utf8Index = utf8.index(utf8.startIndex, offsetBy: offset, limitedBy: utf8.endIndex)
        else {
            return nil
        }
        return utf8Index.samePosition(in: self)
    }
}

public struct TagLink: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    public typealias Value = String
    public static let name: String = "tagLink"
}

public struct MentionLink: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    public typealias Value = String
    public static let name: String = "mentionLink"
}

public extension AttributeScopes {
    struct RichTextAttributes: AttributeScope {
        public let tagLink: TagLink
        public let mentionLink: MentionLink
    }

    var richText: RichTextAttributes.Type { RichTextAttributes.self }
}

// MARK: AttributedString to facets (not tested):

extension AttributedString {
    public func toFacets() -> [AppBskyRichtextFacet]? {
        var facets: [AppBskyRichtextFacet] = []
        let fullString = String(characters[...]) // Convert entire AttributedString to String once for efficiency

        for run in runs {
            let range = run.range
            guard
                let startOffset = utf8Offset(at: range.lowerBound, in: self, fullString: fullString),
                let endOffset = utf8Offset(at: range.upperBound, in: self, fullString: fullString),
                startOffset != endOffset
            else {
                continue // Skip the current iteration if offsets are nil or identical
            }

            var features: [AppBskyRichtextFacet.AppBskyRichtextFacetFeaturesUnion] = []

            // Process any linked URLs to determine facet features
            if let url = run.link {
                let urlString = url.absoluteString
                if urlString.starts(with: "mention://") {
                    let encodedDID = String(urlString.dropFirst("mention://".count))
                    let did = encodedDID.removingPercentEncoding ?? encodedDID
                    features.append(.appBskyRichtextFacetMention(AppBskyRichtextFacet.Mention(did: did)))
                } else if urlString.starts(with: "tag://") {
                    let tag = String(urlString.dropFirst("tag://".count))
                    features.append(.appBskyRichtextFacetTag(AppBskyRichtextFacet.Tag(tag: tag)))
                } else {
                    features.append(
                        .appBskyRichtextFacetLink(AppBskyRichtextFacet.Link(uri: URI(uriString: urlString))))
                }
            }
            if features.isEmpty {
                continue // Skip if no features were extracted
            }

            let byteSlice = AppBskyRichtextFacet.ByteSlice(byteStart: startOffset, byteEnd: endOffset)
            let facet = AppBskyRichtextFacet(index: byteSlice, features: features)
            facets.append(facet)
        }

        // Return nil if no facets were detected
        return facets.isEmpty ? nil : facets
    }

    /// Calculates the UTF-8 byte offset of a given `AttributedString.Index` within the original `String`.
    /// - Parameters:
    ///   - position: The `AttributedString.Index` to find the UTF-8 offset for.
    ///   - attributedString: The `AttributedString` derived from the original string.
    ///   - fullString: The original `String` from which the `AttributedString` was created.
    /// - Returns: The UTF-8 byte offset of the character at `position`, or `nil` if the index is out of range.
    private func utf8Offset(
        at position: AttributedString.Index, in attributedString: AttributedString, fullString: String
    ) -> Int? {
        if position >= attributedString.endIndex {
            print(position, attributedString.endIndex)
            print("Index at or beyond endIndex, handling as a boundary case.")
            return fullString.utf8.count // Return the total count of UTF-8 bytes as the offset
        }

        guard let stringIndex = String.Index(position, within: fullString) else {
            print("Invalid position conversion from AttributedString.Index to String.Index.")
            return nil
        }

        let utf8Offset = fullString.utf8.prefix(upTo: stringIndex).count
        return utf8Offset
    }
}
