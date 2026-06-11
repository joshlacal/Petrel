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

    /**
     * Join link view to be used within a group view, so the convo is surrounding, not specified inside this view.
     */
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

    /**
     * Preview that can be shown in feeds, including to unauthenticated viewers.
     */
    @Serializable
    data class ChatBskyGroupDefsJoinLinkPreviewView(
        @SerialName("convoId")
        val convoId: String,        @SerialName("code")
        val code: String,        @SerialName("name")
        val name: String,        @SerialName("owner")
        val owner: ChatBskyActorDefsProfileViewBasic,        @SerialName("memberCount")
        val memberCount: Int,        @SerialName("memberLimit")
        val memberLimit: Int,        @SerialName("requireApproval")
        val requireApproval: Boolean,        @SerialName("joinRule")
        val joinRule: ChatBskyGroupDefsJoinRule,/** Present only if the request is authenticated and the user is a member of the group. */        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView? = null,        @SerialName("viewer")
        val viewer: ChatBskyGroupDefsJoinLinkViewerState? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyGroupDefsJoinLinkPreviewView"
        }
    }

    /**
     * Preview for a disabled join link. Carries only the code so clients can correlate with the input and render a disabled state.
     */
    @Serializable
    data class ChatBskyGroupDefsDisabledJoinLinkPreviewView(
        @SerialName("code")
        val code: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyGroupDefsDisabledJoinLinkPreviewView"
        }
    }

    /**
     * Preview for a join link code that does not map to an existing link. Carries only the code so clients can correlate with the input and render an invalid state.
     */
    @Serializable
    data class ChatBskyGroupDefsInvalidJoinLinkPreviewView(
        @SerialName("code")
        val code: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyGroupDefsInvalidJoinLinkPreviewView"
        }
    }

    @Serializable
    data class ChatBskyGroupDefsJoinLinkViewerState(
        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyGroupDefsJoinLinkViewerState"
        }
    }

    /**
     * A join request from the perspective of the group owner.
     */
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

    /**
     * A join request from the perspective of the requester, including enough group context to render the request in a list (e.g. group name, owner, member count).
     */
    @Serializable
    data class ChatBskyGroupDefsJoinRequestConvoView(
        @SerialName("convoId")
        val convoId: String,        @SerialName("name")
        val name: String,        @SerialName("owner")
        val owner: ChatBskyActorDefsProfileViewBasic,        @SerialName("memberCount")
        val memberCount: Int,        @SerialName("memberLimit")
        val memberLimit: Int,        @SerialName("viewer")
        val viewer: ChatBskyGroupDefsJoinLinkViewerState    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyGroupDefsJoinRequestConvoView"
        }
    }
