// Lexicon: 1, ID: place.stream.moderation.permission
// Record granting moderation permissions to a user for this streamer's content.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamModerationPermissionDefs {
    const val TYPE_IDENTIFIER = "place.stream.moderation.permission"
}

    /**
     * Record granting moderation permissions to a user for this streamer's content.
     */
    @Serializable
    data class PlaceStreamModerationPermission(
/** The DID of the user granted moderator permissions. */        @SerialName("moderator")
        val moderator: DID,/** Array of permissions granted to this moderator. 'ban' covers blocks/bans (with optional expiration), 'hide' covers message gates, 'livestream.manage' allows updating livestream metadata. */        @SerialName("permissions")
        val permissions: List<String>,/** Client-declared timestamp when this moderator was added. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Optional expiration time for this delegation. If set, the delegation is invalid after this time. */        @SerialName("expirationTime")
        val expirationTime: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
