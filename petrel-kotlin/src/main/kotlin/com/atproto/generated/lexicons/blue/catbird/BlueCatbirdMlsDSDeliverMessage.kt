// Lexicon: 1, ID: blue.catbird.mlsDS.deliverMessage
// Accept an inbound MLS message from a remote DS and store it for local subscribers. Deliver a federated MLS message to a local DS for storage and SSE fanout.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSDeliverMessageDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.deliverMessage"
}

    /**
     * Signed delivery acknowledgment
     */
    @Serializable
    data class BlueCatbirdMlsDSDeliverMessageDeliveryAck(
/** Signed acknowledgment token */        @SerialName("sig")
        val sig: String,        @SerialName("msgId")
        val msgId: String? = null,        @SerialName("convoId")
        val convoId: String? = null,        @SerialName("epoch")
        val epoch: Int? = null,        @SerialName("term")
        val term: Int? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsDSDeliverMessageDeliveryAck"
        }
    }

@Serializable
    data class BlueCatbirdMlsDSDeliverMessageInput(
// Conversation ID        @SerialName("convoId")
        val convoId: String,// Unique message ID (ULID)        @SerialName("msgId")
        val msgId: String,// MLS epoch of the message        @SerialName("epoch")
        val epoch: Int,// DID of the sending delivery service        @SerialName("senderDsDid")
        val senderDsDid: String,// Encrypted MLS message payload        @SerialName("ciphertext")
        val ciphertext: Bytes,// Padded size of the plaintext for uniform message lengths        @SerialName("paddedSize")
        val paddedSize: Int,// Message type (default: 'app')        @SerialName("messageType")
        val messageType: String? = null,// Delivery tracking ID (ULID)        @SerialName("deliveryId")
        val deliveryId: String,// Current sequencer term for CAS validation        @SerialName("sequencerTerm")
        val sequencerTerm: Int    )

    @Serializable
    data class BlueCatbirdMlsDSDeliverMessageOutput(
// Whether the message was accepted        @SerialName("accepted")
        val accepted: Boolean,// Assigned sequence number        @SerialName("seq")
        val seq: Int,// Echo of the delivery ID        @SerialName("deliveryId")
        val deliveryId: String,        @SerialName("ack")
        val ack: BlueCatbirdMlsDSDeliverMessageDeliveryAck? = null    )

sealed class BlueCatbirdMlsDSDeliverMessageError(val name: String, val description: String?) {
        object ConversationNotFound: BlueCatbirdMlsDSDeliverMessageError("ConversationNotFound", "")
        object NotSequencer: BlueCatbirdMlsDSDeliverMessageError("NotSequencer", "")
        object TermStale: BlueCatbirdMlsDSDeliverMessageError("TermStale", "")
    }

/**
 * Accept an inbound MLS message from a remote DS and store it for local subscribers. Deliver a federated MLS message to a local DS for storage and SSE fanout.
 *
 * Endpoint: blue.catbird.mlsDS.deliverMessage
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.deliverMessage(
input: BlueCatbirdMlsDSDeliverMessageInput): ATProtoResponse<BlueCatbirdMlsDSDeliverMessageOutput> {
    val endpoint = "blue.catbird.mlsDS.deliverMessage"

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
