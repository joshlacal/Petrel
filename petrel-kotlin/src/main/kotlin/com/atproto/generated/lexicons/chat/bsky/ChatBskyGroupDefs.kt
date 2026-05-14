// Lexicon: 1, ID: chat.bsky.group.defs
// [NOTE: This is under active development and should be considered unstable while this note is here].
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupDefsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.defs"
}

@Serializable
enum class ChatBskyGroupDefsLinkEnabledStatus {
    @SerialName("enabled")
    ENABLED,
    @SerialName("disabled")
    DISABLED}

@Serializable
enum class ChatBskyGroupDefsJoinRule {
    @SerialName("anyone")
    ANYONE,
    @SerialName("followedByOwner")
    FOLLOWEDBYOWNER}

    @Serializable
    data class ChatBskyGroupDefsJoinLinkView(
        @SerialName("code")
        val code: String,        @SerialName("enabledStatus")
        val enabledStatus: ChatBskyGroupDefsLinkEnabledStatus,        @SerialName("requireApproval")
        val requireApproval: Boolean,        @SerialName("joinRule")
        val joinRule: ChatBskyGroupDefsJoinRule,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyGroupDefsJoinLinkView"
        }
    }

    @Serializable
    data class ChatBskyGroupDefsGroupPublicView(
        @SerialName("name")
        val name: String,        @SerialName("owner")
        val owner: ChatBskyActorDefsProfileViewBasic,        @SerialName("memberCount")
        val memberCount: Int,        @SerialName("requireApproval")
        val requireApproval: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyGroupDefsGroupPublicView"
        }
    }

    @Serializable
    data class ChatBskyGroupDefsJoinRequestView(
        @SerialName("convoId")
        val convoId: String,        @SerialName("requestedBy")
        val requestedBy: ChatBskyActorDefsProfileViewBasic,        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyGroupDefsJoinRequestView"
        }
    }
