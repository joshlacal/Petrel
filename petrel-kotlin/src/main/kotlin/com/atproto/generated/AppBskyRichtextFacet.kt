// Lexicon: 1, ID: app.bsky.richtext.facet
// Annotation of a sub-string within rich text.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface AppBskyRichtextFacetFeaturesUnion {
    @Serializable
    @SerialName("app.bsky.richtext.facet#Mention")
    data class Mention(val value: Mention) : AppBskyRichtextFacetFeaturesUnion

    @Serializable
    @SerialName("app.bsky.richtext.facet#Link")
    data class Link(val value: Link) : AppBskyRichtextFacetFeaturesUnion

    @Serializable
    @SerialName("app.bsky.richtext.facet#Tag")
    data class Tag(val value: Tag) : AppBskyRichtextFacetFeaturesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyRichtextFacetFeaturesUnion
}

object AppBskyRichtextFacet {
    const val TYPE_IDENTIFIER = "app.bsky.richtext.facet"

        /**
     * Facet feature for mention of another account. The text is usually a handle, including a '@' prefix, but the facet reference is a DID.
     */
    @Serializable
    data class Mention(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#mention"
        }
    }

    /**
     * Facet feature for a URL. The text URL may have been simplified or truncated, but the facet reference should be a complete URL.
     */
    @Serializable
    data class Link(
        @SerialName("uri")
        val uri: URI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#link"
        }
    }

    /**
     * Facet feature for a hashtag. The text usually includes a '#' prefix, but the facet reference should not (except in the case of 'double hash tags').
     */
    @Serializable
    data class Tag(
        @SerialName("tag")
        val tag: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#tag"
        }
    }

    /**
     * Specifies the sub-string range a facet feature applies to. Start index is inclusive, end index is exclusive. Indices are zero-indexed, counting bytes of the UTF-8 encoded text. NOTE: some languages, like Javascript, use UTF-16 or Unicode codepoints for string slice indexing; in these languages, convert to byte arrays before working with facets.
     */
    @Serializable
    data class Byteslice(
        @SerialName("byteStart")
        val byteStart: Int,        @SerialName("byteEnd")
        val byteEnd: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#byteslice"
        }
    }

    @Serializable
data class AppBskyRichtextFacet(
    @SerialName("index")
    val index: Byteslice,    @SerialName("features")
    val features: List<AppBskyRichtextFacetFeaturesUnion>)
}
