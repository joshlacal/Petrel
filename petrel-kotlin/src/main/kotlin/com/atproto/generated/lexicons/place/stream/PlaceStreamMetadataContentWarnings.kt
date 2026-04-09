// Lexicon: 1, ID: place.stream.metadata.contentWarnings
// Content warnings for a stream.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamMetadataContentWarningsDefs {
    const val TYPE_IDENTIFIER = "place.stream.metadata.contentWarnings"
}

@Serializable
data class PlaceStreamMetadataContentWarnings(
    @SerialName("warnings")
    val warnings: List<String>? = null)
