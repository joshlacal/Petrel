// Lexicon: 1, ID: place.stream.badge.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamBadgeDefsDefs {
    const val TYPE_IDENTIFIER = "place.stream.badge.defs"
}

    /**
     * View of a badge record, with fields resolved for display. If the DID in issuer is not the current streamplace node, the signature field shall be required.
     */
    @Serializable
    data class PlaceStreamBadgeDefsBadgeView(
        @SerialName("badgeType")
        val badgeType: String,/** DID of the badge issuer. */        @SerialName("issuer")
        val issuer: DID,/** DID of the badge recipient. */        @SerialName("recipient")
        val recipient: DID,/** TODO: Cryptographic signature of the badge (of a place.stream.key). */        @SerialName("signature")
        val signature: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamBadgeDefsBadgeView"
        }
    }
