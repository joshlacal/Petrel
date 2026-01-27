// Lexicon: 1, ID: blue.catbird.mls.sendMessage
// Send an encrypted message to an MLS conversation
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsSendMessageDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.sendMessage"
}

@Serializable
    data class BlueCatbirdMlsSendMessageInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Client-generated ULID for message deduplication. MUST be included in MLS message AAD.        @SerialName("msgId")
        val msgId: String,// Deprecated: Use msgId instead. Client-generated UUID for idempotent request retries.        @SerialName("idempotencyKey")
        val idempotencyKey: String? = null,// MLS encrypted message ciphertext bytes (MUST be padded to paddedSize). The actual message length MUST be encrypted inside the MLS ciphertext for recipients to strip padding.        @SerialName("ciphertext")
        val ciphertext: ByteArray,// MLS epoch number when message was encrypted        @SerialName("epoch")
        val epoch: Int,// Padded ciphertext size in bytes. Must be 512, 1024, 2048, 4096, 8192, or multiples of 8192 up to 10MB. For metadata privacy, only this bucket size is revealed; the actual message size is encrypted inside the ciphertext.        @SerialName("paddedSize")
        val paddedSize: Int    )

    @Serializable
    data class BlueCatbirdMlsSendMessageOutput(
// Created message identifier (echoed from input msgId)        @SerialName("messageId")
        val messageId: String,// Server timestamp when message was received (bucketed to 2-second intervals)        @SerialName("receivedAt")
        val receivedAt: ATProtocolDate,// Server-assigned sequence number for this message. Monotonically increasing within the conversation.        @SerialName("seq")
        val seq: Int,// MLS epoch number (echoed from input for client confirmation)        @SerialName("epoch")
        val epoch: Int    )

sealed class BlueCatbirdMlsSendMessageError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsSendMessageError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsSendMessageError("NotMember", "Caller is not a member of the conversation")
        object InvalidAsset: BlueCatbirdMlsSendMessageError("InvalidAsset", "Payload or attachment pointer is invalid")
        object EpochMismatch: BlueCatbirdMlsSendMessageError("EpochMismatch", "Message epoch does not match current conversation epoch")
        object MessageTooLarge: BlueCatbirdMlsSendMessageError("MessageTooLarge", "Message exceeds maximum size policy")
    }

/**
 * Send an encrypted message to an MLS conversation
 *
 * Endpoint: blue.catbird.mls.sendMessage
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.sendMessage(
input: BlueCatbirdMlsSendMessageInput): ATProtoResponse<BlueCatbirdMlsSendMessageOutput> {
    val endpoint = "blue.catbird.mls.sendMessage"

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
