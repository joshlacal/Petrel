// Lexicon: 1, ID: blue.catbird.mlsChat.handleBlockChange
// Notify server of Bluesky block change affecting conversation membership Client notifies server when a Bluesky block is created or removed that affects MLS conversations. Server checks if both users are in any conversations together and notifies admins of conflicts. Enables reactive moderation when blocks occur after users have already joined conversations.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatHandleBlockChangeDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.handleBlockChange"
}

    /**
     * A conversation affected by a block change
     */
    @Serializable
    data class BlueCatbirdMlsChatHandleBlockChangeAffectedConvo(
/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Action taken or required by admins */        @SerialName("action")
        val action: String,/** Whether conversation admins were notified via SSE */        @SerialName("adminNotified")
        val adminNotified: Boolean,/** When admin notification was sent (if applicable) */        @SerialName("notificationSentAt")
        val notificationSentAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatHandleBlockChangeAffectedConvo"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatHandleBlockChangeInput(
// User who created or removed the block        @SerialName("blockerDid")
        val blockerDid: DID,// User who was blocked or unblocked        @SerialName("blockedDid")
        val blockedDid: DID,// Whether the block was created or removed        @SerialName("action")
        val action: String,// AT-URI of the block record on Bluesky (for verification)        @SerialName("blockUri")
        val blockUri: ATProtocolURI? = null    )

    @Serializable
    data class BlueCatbirdMlsChatHandleBlockChangeOutput(
// Conversations where both users are members (block conflicts)        @SerialName("affectedConvos")
        val affectedConvos: List<BlueCatbirdMlsChatHandleBlockChangeAffectedConvo>    )

sealed class BlueCatbirdMlsChatHandleBlockChangeError(val name: String, val description: String?) {
        object BlockNotVerified: BlueCatbirdMlsChatHandleBlockChangeError("BlockNotVerified", "Could not verify block status with Bluesky")
    }

/**
 * Notify server of Bluesky block change affecting conversation membership Client notifies server when a Bluesky block is created or removed that affects MLS conversations. Server checks if both users are in any conversations together and notifies admins of conflicts. Enables reactive moderation when blocks occur after users have already joined conversations.
 *
 * Endpoint: blue.catbird.mlsChat.handleBlockChange
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.handleBlockChange(
input: BlueCatbirdMlsChatHandleBlockChangeInput): ATProtoResponse<BlueCatbirdMlsChatHandleBlockChangeOutput> {
    val endpoint = "blue.catbird.mlsChat.handleBlockChange"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
