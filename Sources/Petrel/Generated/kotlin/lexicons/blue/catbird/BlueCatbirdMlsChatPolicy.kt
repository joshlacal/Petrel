// Lexicon: 1, ID: blue.catbird.mlsChat.policy
// Chat policy preferences for MLS messaging. Single mutable record per user.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatPolicyDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.policy"
}

    /**
     * Chat policy preferences for MLS messaging. Single mutable record per user.
     */
    @Serializable
    data class BlueCatbirdMlsChatPolicy(
/** Who can initiate conversations: 'everyone', 'mutuals', 'following', 'nobody' */        @SerialName("whoCanMessageMe")
        val whoCanMessageMe: String? = null,/** Allow followers to message even if whoCanMessageMe would exclude them */        @SerialName("allowFollowersBypass")
        val allowFollowersBypass: Boolean? = null,/** Allow users you follow to message even if whoCanMessageMe would exclude them */        @SerialName("allowFollowingBypass")
        val allowFollowingBypass: Boolean? = null,/** Auto-expire conversations after N days of inactivity */        @SerialName("autoExpireDays")
        val autoExpireDays: Int? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
