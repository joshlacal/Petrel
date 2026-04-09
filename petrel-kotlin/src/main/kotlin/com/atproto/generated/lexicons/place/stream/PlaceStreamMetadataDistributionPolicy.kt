// Lexicon: 1, ID: place.stream.metadata.distributionPolicy
// Distribution and rebroadcast policy.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamMetadataDistributionPolicyDefs {
    const val TYPE_IDENTIFIER = "place.stream.metadata.distributionPolicy"
}

@Serializable
data class PlaceStreamMetadataDistributionPolicy(
// Duration in seconds after which segments should be deleted. Each segment will expire N seconds after its creation time. -1 to allow indefinite archival.    @SerialName("deleteAfter")
    val deleteAfter: Int? = null,// List of did:webs of the broadcasters you want to allow to distribute your content. "*" allows anyone. Starting a line with a "!" bans that broadcaster.    @SerialName("allowedBroadcasters")
    val allowedBroadcasters: List<String>? = null)
