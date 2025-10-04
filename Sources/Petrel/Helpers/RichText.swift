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
                            mentionFeature.did.didString().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                                ?? mentionFeature.did.didString()
                        let atURIString = "mention://" + encodedDID
                        if let url = URL(string: atURIString) {
                            attributedString[range].link = url
                        }
                        attributedString[range].richText.mentionLink = mentionFeature.did.didString()
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
    public func toFacets() throws -> [AppBskyRichtextFacet]? {
        var facets: [AppBskyRichtextFacet] = []
        let fullString = String(characters[...]) // Convert entire AttributedString to String once for efficiency

        for run in runs {
            let range = run.range
            guard
                let lowerBound = String.Index(range.lowerBound, within: fullString),
                let upperBound = String.Index(range.upperBound, within: fullString),
                lowerBound < upperBound
            else {
                continue // Skip the current iteration if offsets are nil or identical
            }

            // Derive UTF-8 offsets directly from the source string to avoid character/byte mismatches
            let byteStart = fullString[..<lowerBound].utf8.count
            let byteEnd = byteStart + fullString[lowerBound..<upperBound].utf8.count

            var features: [AppBskyRichtextFacet.AppBskyRichtextFacetFeaturesUnion] = []

            // Process any linked URLs to determine facet features
            if let url = run.link {
                let urlString = url.absoluteString
                if urlString.starts(with: "mention://") {
                    let encodedDID = String(urlString.dropFirst("mention://".count))
                    let did = encodedDID.removingPercentEncoding ?? encodedDID
                    try features.append(.appBskyRichtextFacetMention(AppBskyRichtextFacet.Mention(did: DID(didString: did))))
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

            let byteSlice = AppBskyRichtextFacet.ByteSlice(byteStart: byteStart, byteEnd: byteEnd)
            let facet = AppBskyRichtextFacet(index: byteSlice, features: features)
            facets.append(facet)
        }

        // Return nil if no facets were detected
        return facets.isEmpty ? nil : facets
    }

}
