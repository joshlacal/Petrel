// Lexicon: 1, ID: place.stream.metadata.contentRights
// Content rights and attribution information.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamMetadataContentRightsDefs {
    const val TYPE_IDENTIFIER = "place.stream.metadata.contentRights"
}

@Serializable
data class PlaceStreamMetadataContentRights(
// Name of the creator of the work.    @SerialName("creator")
    val creator: String? = null,// Copyright notice for the work.    @SerialName("copyrightNotice")
    val copyrightNotice: String? = null,// Year of creation or publication.    @SerialName("copyrightYear")
    val copyrightYear: Int? = null,// License URL or identifier.    @SerialName("license")
    val license: String? = null,// Credit line for the work.    @SerialName("creditLine")
    val creditLine: String? = null)
