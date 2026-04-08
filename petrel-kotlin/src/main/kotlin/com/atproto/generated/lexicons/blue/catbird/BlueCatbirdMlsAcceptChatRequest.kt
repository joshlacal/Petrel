// Lexicon: 1, ID: blue.catbird.mls.acceptChatRequest
// Accept a chat request, create MLS group, and deliver held messages
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsAcceptChatRequestDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.acceptChatRequest"
}

    @Serializable
    data class BlueCatbirdMlsAcceptChatRequestDeliveredMessage(
/** Message ID */        @SerialName("id")
        val id: String,/** MLS encrypted message */        @SerialName("ciphertext")
        val ciphertext: ByteArray,/** Padded message size */        @SerialName("paddedSize")
        val paddedSize: Int,/** Message order in request */        @SerialName("sequence")
        val sequence: Int,/** Ephemeral public key if present */        @SerialName("ephPubKey")
        val ephPubKey: ByteArray?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsAcceptChatRequestDeliveredMessage"
        }
    }

@Serializable
    data class BlueCatbirdMlsAcceptChatRequestInput(
// ID of the request to accept        @SerialName("requestId")
        val requestId: String,// MLS Welcome message for sender to join group        @SerialName("welcomeData")
        val welcomeData: ByteArray? = null    )

    @Serializable
    data class BlueCatbirdMlsAcceptChatRequestOutput(
// Created conversation ID        @SerialName("convoId")
        val convoId: String,// Held messages now available to decrypt        @SerialName("heldMessages")
        val heldMessages: List<BlueCatbirdMlsAcceptChatRequestDeliveredMessage>,// Acceptance timestamp        @SerialName("acceptedAt")
        val acceptedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsAcceptChatRequestError(val name: String, val description: String?) {
        object RequestNotFound: BlueCatbirdMlsAcceptChatRequestError("RequestNotFound", "")
        object RequestExpired: BlueCatbirdMlsAcceptChatRequestError("RequestExpired", "")
        object AlreadyProcessed: BlueCatbirdMlsAcceptChatRequestError("AlreadyProcessed", "")
    }

/**
 * Accept a chat request, create MLS group, and deliver held messages
 *
 * Endpoint: blue.catbird.mls.acceptChatRequest
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.acceptChatRequest(
input: BlueCatbirdMlsAcceptChatRequestInput): ATProtoResponse<BlueCatbirdMlsAcceptChatRequestOutput> {
    val endpoint = "blue.catbird.mls.acceptChatRequest"

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
