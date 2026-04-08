// Lexicon: 1, ID: blue.catbird.mlsDS.getConvoEvents
// Paginated retrieval of conversation events for federation reconciliation. Fetch a page of conversation events (messages) after a given sequence number.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSGetConvoEventsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.getConvoEvents"
}

    /**
     * A single conversation event (message) with metadata.
     */
    @Serializable
    data class BlueCatbirdMlsDSGetConvoEventsConvoEventEntry(
/** Sequence number */        @SerialName("seq")
        val seq: Int,/** MLS epoch */        @SerialName("epoch")
        val epoch: Int,/** Message ID */        @SerialName("msgId")
        val msgId: String,/** Message type (e.g., 'app') */        @SerialName("messageType")
        val messageType: String,/** Encrypted message payload */        @SerialName("ciphertext")
        val ciphertext: Bytes,/** Padded plaintext size */        @SerialName("paddedSize")
        val paddedSize: Int,/** Creation timestamp */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsDSGetConvoEventsConvoEventEntry"
        }
    }

@Serializable
    data class BlueCatbirdMlsDSGetConvoEventsParameters(
// Conversation ID        @SerialName("convoId")
        val convoId: String,// Return events after this sequence number (exclusive). Defaults to 0.        @SerialName("afterSeq")
        val afterSeq: Int? = null,// Maximum number of events to return (1-1000, default 200).        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsDSGetConvoEventsOutput(
// Conversation ID        @SerialName("convoId")
        val convoId: String,// Lower bound sequence number (exclusive)        @SerialName("fromSeqExclusive")
        val fromSeqExclusive: Int,// Upper bound sequence number (inclusive)        @SerialName("toSeqInclusive")
        val toSeqInclusive: Int,// Ordered list of conversation events        @SerialName("events")
        val events: List<BlueCatbirdMlsDSGetConvoEventsConvoEventEntry>    )

sealed class BlueCatbirdMlsDSGetConvoEventsError(val name: String, val description: String?) {
        object ConversationNotFound: BlueCatbirdMlsDSGetConvoEventsError("ConversationNotFound", "")
        object NotAuthorized: BlueCatbirdMlsDSGetConvoEventsError("NotAuthorized", "")
    }

/**
 * Paginated retrieval of conversation events for federation reconciliation. Fetch a page of conversation events (messages) after a given sequence number.
 *
 * Endpoint: blue.catbird.mlsDS.getConvoEvents
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.getConvoEvents(
parameters: BlueCatbirdMlsDSGetConvoEventsParameters): ATProtoResponse<BlueCatbirdMlsDSGetConvoEventsOutput> {
    val endpoint = "blue.catbird.mlsDS.getConvoEvents"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
