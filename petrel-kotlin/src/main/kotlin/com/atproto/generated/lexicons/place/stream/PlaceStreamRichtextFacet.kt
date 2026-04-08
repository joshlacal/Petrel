// Lexicon: 1, ID: place.stream.richtext.facet
// Annotation of a sub-string within rich text.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamRichtextFacetDefs {
    const val TYPE_IDENTIFIER = "place.stream.richtext.facet"
}

@Serializable
sealed interface PlaceStreamRichtextFacetFeaturesUnion {
    @Serializable
    @SerialName("place.stream.richtext.facet#AppBskyRichtextFacetMention")
    data class AppBskyRichtextFacetMention(val value: AppBskyRichtextFacetMention) : PlaceStreamRichtextFacetFeaturesUnion

    @Serializable
    @SerialName("place.stream.richtext.facet#AppBskyRichtextFacetLink")
    data class AppBskyRichtextFacetLink(val value: AppBskyRichtextFacetLink) : PlaceStreamRichtextFacetFeaturesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : PlaceStreamRichtextFacetFeaturesUnion
}

@Serializable
data class PlaceStreamRichtextFacet(
    @SerialName("index")
    val index: AppBskyRichtextFacetByteSlice,    @SerialName("features")
    val features: List<PlaceStreamRichtextFacetFeaturesUnion>)
