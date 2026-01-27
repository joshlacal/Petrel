// Lexicon: 1, ID: app.bsky.richtext.facet
// Annotation of a sub-string within rich text.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyRichtextFacetDefs {
    const val TYPE_IDENTIFIER = "app.bsky.richtext.facet"
}

@Serializable
sealed interface AppBskyRichtextFacetFeaturesUnion {
    @Serializable
    @SerialName("app.bsky.richtext.facet#AppBskyRichtextFacetMention")
    data class AppBskyRichtextFacetMention(val value: AppBskyRichtextFacetMention) : AppBskyRichtextFacetFeaturesUnion

    @Serializable
    @SerialName("app.bsky.richtext.facet#AppBskyRichtextFacetLink")
    data class AppBskyRichtextFacetLink(val value: AppBskyRichtextFacetLink) : AppBskyRichtextFacetFeaturesUnion

    @Serializable
    @SerialName("app.bsky.richtext.facet#AppBskyRichtextFacetTag")
    data class AppBskyRichtextFacetTag(val value: AppBskyRichtextFacetTag) : AppBskyRichtextFacetFeaturesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyRichtextFacetFeaturesUnion
}

    /**
     * Facet feature for mention of another account. The text is usually a handle, including a '@' prefix, but the facet reference is a DID.
     */
    @Serializable
    data class AppBskyRichtextFacetMention(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyRichtextFacetMention"
        }
    }

    /**
     * Facet feature for a URL. The text URL may have been simplified or truncated, but the facet reference should be a complete URL.
     */
    @Serializable
    data class AppBskyRichtextFacetLink(
        @SerialName("uri")
        val uri: URI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyRichtextFacetLink"
        }
    }

    /**
     * Facet feature for a hashtag. The text usually includes a '#' prefix, but the facet reference should not (except in the case of 'double hash tags').
     */
    @Serializable
    data class AppBskyRichtextFacetTag(
        @SerialName("tag")
        val tag: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyRichtextFacetTag"
        }
    }

    /**
     * Specifies the sub-string range a facet feature applies to. Start index is inclusive, end index is exclusive. Indices are zero-indexed, counting bytes of the UTF-8 encoded text. NOTE: some languages, like Javascript, use UTF-16 or Unicode codepoints for string slice indexing; in these languages, convert to byte arrays before working with facets.
     */
    @Serializable
    data class AppBskyRichtextFacetByteSlice(
        @SerialName("byteStart")
        val byteStart: Int,        @SerialName("byteEnd")
        val byteEnd: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyRichtextFacetByteSlice"
        }
    }

@Serializable
data class AppBskyRichtextFacet(
    @SerialName("index")
    val index: AppBskyRichtextFacetByteSlice,    @SerialName("features")
    val features: List<AppBskyRichtextFacetFeaturesUnion>)
