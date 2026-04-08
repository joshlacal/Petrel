// Lexicon: 1, ID: blue.catbird.mlsChat.acceptChatRequest
// Accept a chat request, create MLS group, and deliver held messages
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatAcceptChatRequestDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.acceptChatRequest"
}

    @Serializable
    data class BlueCatbirdMlsChatAcceptChatRequestDeliveredMessage(
/** Message ID */        @SerialName("id")
        val id: String,/** MLS encrypted message */        @SerialName("ciphertext")
        val ciphertext: ByteArray,/** Padded message size */        @SerialName("paddedSize")
        val paddedSize: Int,/** Message order in request */        @SerialName("sequence")
        val sequence: Int,/** Ephemeral public key if present */        @SerialName("ephPubKey")
        val ephPubKey: ByteArray?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatAcceptChatRequestDeliveredMessage"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatAcceptChatRequestInput(
// ID of the request to accept        @SerialName("requestId")
        val requestId: String,// MLS Welcome message for sender to join group        @SerialName("welcomeData")
        val welcomeData: ByteArray? = null    )

    @Serializable
    data class BlueCatbirdMlsChatAcceptChatRequestOutput(
// Created conversation ID        @SerialName("convoId")
        val convoId: String,// Held messages now available to decrypt        @SerialName("heldMessages")
        val heldMessages: List<BlueCatbirdMlsChatAcceptChatRequestDeliveredMessage>,// Acceptance timestamp        @SerialName("acceptedAt")
        val acceptedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatAcceptChatRequestError(val name: String, val description: String?) {
        object RequestNotFound: BlueCatbirdMlsChatAcceptChatRequestError("RequestNotFound", "")
        object RequestExpired: BlueCatbirdMlsChatAcceptChatRequestError("RequestExpired", "")
        object AlreadyProcessed: BlueCatbirdMlsChatAcceptChatRequestError("AlreadyProcessed", "")
    }

/**
 * Accept a chat request, create MLS group, and deliver held messages
 *
 * Endpoint: blue.catbird.mlsChat.acceptChatRequest
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.acceptChatRequest(
input: BlueCatbirdMlsChatAcceptChatRequestInput): ATProtoResponse<BlueCatbirdMlsChatAcceptChatRequestOutput> {
    val endpoint = "blue.catbird.mlsChat.acceptChatRequest"

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
