// Lexicon: 1, ID: blue.catbird.mlsDS.deliverWelcome
// Accept a Welcome message for a new member from a remote DS. Deliver a federated MLS Welcome message to add a user to a group on the local DS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSDeliverWelcomeDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.deliverWelcome"
}

@Serializable
    data class BlueCatbirdMlsDSDeliverWelcomeInput(
// Conversation ID        @SerialName("convoId")
        val convoId: String,// DID of the recipient user        @SerialName("recipientDid")
        val recipientDid: String,// DID of the sending delivery service        @SerialName("senderDsDid")
        val senderDsDid: String,// Hash of the consumed key package        @SerialName("keyPackageHash")
        val keyPackageHash: String,// Serialized MLS Welcome message        @SerialName("welcomeData")
        val welcomeData: Bytes,// Initial epoch of the group for the new member        @SerialName("initialEpoch")
        val initialEpoch: Int    )

    @Serializable
    data class BlueCatbirdMlsDSDeliverWelcomeOutput(
// Whether the welcome was accepted        @SerialName("accepted")
        val accepted: Boolean,        @SerialName("ack")
        val ack: BlueCatbirdMlsDSDeliverMessageDeliveryAck? = null    )

sealed class BlueCatbirdMlsDSDeliverWelcomeError(val name: String, val description: String?) {
        object RecipientNotFound: BlueCatbirdMlsDSDeliverWelcomeError("RecipientNotFound", "")
        object NotSequencer: BlueCatbirdMlsDSDeliverWelcomeError("NotSequencer", "")
    }

/**
 * Accept a Welcome message for a new member from a remote DS. Deliver a federated MLS Welcome message to add a user to a group on the local DS.
 *
 * Endpoint: blue.catbird.mlsDS.deliverWelcome
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.deliverWelcome(
input: BlueCatbirdMlsDSDeliverWelcomeInput): ATProtoResponse<BlueCatbirdMlsDSDeliverWelcomeOutput> {
    val endpoint = "blue.catbird.mlsDS.deliverWelcome"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
