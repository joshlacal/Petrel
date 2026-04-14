// Lexicon: 1, ID: blue.catbird.mlsChat.sendMessage
// Send an encrypted message with optional reaction support (consolidates sendMessage + reaction sub-actions) Send an encrypted message to an MLS conversation. Supports application messages, reactions (add/remove), and ephemeral delivery. The msgId serves as the idempotency key.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatSendMessageDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.sendMessage"
}

@Serializable
    data class BlueCatbirdMlsChatSendMessageInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Client-generated ULID for message deduplication. MUST be included in MLS message AAD.        @SerialName("msgId")
        val msgId: String,// MLS encrypted message ciphertext bytes (MUST be padded to paddedSize)        @SerialName("ciphertext")
        val ciphertext: Bytes,// MLS epoch number when message was encrypted        @SerialName("epoch")
        val epoch: Int,// Padded ciphertext size in bytes (512, 1024, 2048, 4096, 8192, or multiples of 8192)        @SerialName("paddedSize")
        val paddedSize: Int,// Delivery mode: 'persistent' (stored, replayed on sync) or 'ephemeral' (SSE only, not stored)        @SerialName("delivery")
        val delivery: String? = null,// Optional sub-action: 'addReaction' or 'removeReaction' for reaction messages        @SerialName("action")
        val action: String? = null,// Emoji for reaction (required when action is 'addReaction' or 'removeReaction')        @SerialName("reactionEmoji")
        val reactionEmoji: String? = null,// Message ID being reacted to (required when action is 'addReaction' or 'removeReaction')        @SerialName("targetMessageId")
        val targetMessageId: String? = null,// MLS confirmation tag. Server rejects with TreeStateDiverged if it does not match the canonical tree.        @SerialName("confirmationTag")
        val confirmationTag: Bytes? = null    )

    @Serializable
    data class BlueCatbirdMlsChatSendMessageOutput(
// Created message identifier (echoed from input msgId)        @SerialName("messageId")
        val messageId: String,// Server timestamp when message was received (bucketed to 2-second intervals)        @SerialName("receivedAt")
        val receivedAt: ATProtocolDate,// Server-assigned monotonically increasing sequence number        @SerialName("seq")
        val seq: Int,// MLS epoch number (echoed from input)        @SerialName("epoch")
        val epoch: Int    )

sealed class BlueCatbirdMlsChatSendMessageError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatSendMessageError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatSendMessageError("NotMember", "Caller is not a member of the conversation")
        object EpochMismatch: BlueCatbirdMlsChatSendMessageError("EpochMismatch", "Message epoch does not match current conversation epoch")
        object MessageTooLarge: BlueCatbirdMlsChatSendMessageError("MessageTooLarge", "Message exceeds maximum size policy")
        object InvalidReaction: BlueCatbirdMlsChatSendMessageError("InvalidReaction", "Missing reactionEmoji or targetMessageId for reaction action")
        object InvalidAsset: BlueCatbirdMlsChatSendMessageError("InvalidAsset", "Payload or attachment pointer is invalid")
        object TreeStateDiverged: BlueCatbirdMlsChatSendMessageError("TreeStateDiverged", "Client MLS tree state does not match server canonical tree. Client must re-join via external commit.")
    }

/**
 * Send an encrypted message with optional reaction support (consolidates sendMessage + reaction sub-actions) Send an encrypted message to an MLS conversation. Supports application messages, reactions (add/remove), and ephemeral delivery. The msgId serves as the idempotency key.
 *
 * Endpoint: blue.catbird.mlsChat.sendMessage
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.sendMessage(
input: BlueCatbirdMlsChatSendMessageInput): ATProtoResponse<BlueCatbirdMlsChatSendMessageOutput> {
    val endpoint = "blue.catbird.mlsChat.sendMessage"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
