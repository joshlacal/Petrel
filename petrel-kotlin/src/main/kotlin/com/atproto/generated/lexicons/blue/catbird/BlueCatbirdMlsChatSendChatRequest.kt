// Lexicon: 1, ID: blue.catbird.mlsChat.sendChatRequest
// Send a chat request to a user not yet in conversation. The request holds encrypted message(s) until accepted.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatSendChatRequestDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.sendChatRequest"
}

    @Serializable
    data class BlueCatbirdMlsChatSendChatRequestHeldMessage(
/** MLS encrypted message ciphertext */        @SerialName("ciphertext")
        val ciphertext: ByteArray,/** Padded ciphertext size (power of 2 buckets) */        @SerialName("paddedSize")
        val paddedSize: Int,/** Optional ephemeral public key for forward secrecy */        @SerialName("ephPubKey")
        val ephPubKey: ByteArray?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSendChatRequestHeldMessage"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatSendChatRequestInput(
// DID of the user to send chat request to        @SerialName("recipientDid")
        val recipientDid: String,// Optional short plain-text preview message (not E2EE, max 200 chars)        @SerialName("previewText")
        val previewText: String? = null,// Encrypted messages to hold until request accepted (max 5)        @SerialName("heldMessages")
        val heldMessages: List<BlueCatbirdMlsChatSendChatRequestHeldMessage>? = null,// If true, this is an invite to an existing group        @SerialName("isGroupInvite")
        val isGroupInvite: Boolean? = null,// Conversation ID if this is a group invite        @SerialName("groupId")
        val groupId: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatSendChatRequestOutput(
// Unique request identifier (ULID)        @SerialName("requestId")
        val requestId: String,// Request status (bypassed if social graph allows)        @SerialName("status")
        val status: String,// Request creation timestamp        @SerialName("createdAt")
        val createdAt: ATProtocolDate,// Request expiration timestamp        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate,// Conversation ID if request was bypassed        @SerialName("convoId")
        val convoId: String? = null    )

sealed class BlueCatbirdMlsChatSendChatRequestError(val name: String, val description: String?) {
        object BlockedByRecipient: BlueCatbirdMlsChatSendChatRequestError("BlockedByRecipient", "")
        object RateLimited: BlueCatbirdMlsChatSendChatRequestError("RateLimited", "")
        object RecipientNotFound: BlueCatbirdMlsChatSendChatRequestError("RecipientNotFound", "")
        object DuplicateRequest: BlueCatbirdMlsChatSendChatRequestError("DuplicateRequest", "")
        object SelfRequest: BlueCatbirdMlsChatSendChatRequestError("SelfRequest", "")
    }

/**
 * Send a chat request to a user not yet in conversation. The request holds encrypted message(s) until accepted.
 *
 * Endpoint: blue.catbird.mlsChat.sendChatRequest
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.sendChatRequest(
input: BlueCatbirdMlsChatSendChatRequestInput): ATProtoResponse<BlueCatbirdMlsChatSendChatRequestOutput> {
    val endpoint = "blue.catbird.mlsChat.sendChatRequest"

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
