// Lexicon: 1, ID: blue.catbird.mlsDS.transferSequencer
// Accept a sequencer role transfer from the current sequencer DS. Transfer sequencer responsibility for a conversation to this DS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSTransferSequencerDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.transferSequencer"
}

@Serializable
    data class BlueCatbirdMlsDSTransferSequencerInput(
// Conversation ID        @SerialName("convoId")
        val convoId: String,// Current epoch at time of transfer (informational)        @SerialName("currentEpoch")
        val currentEpoch: Int? = null,// New sequencer term to establish        @SerialName("newSequencerTerm")
        val newSequencerTerm: Int    )

    @Serializable
    data class BlueCatbirdMlsDSTransferSequencerOutput(
// Whether the transfer was accepted        @SerialName("accepted")
        val accepted: Boolean,// Confirmed new sequencer term        @SerialName("newSequencerTerm")
        val newSequencerTerm: Int    )

sealed class BlueCatbirdMlsDSTransferSequencerError(val name: String, val description: String?) {
        object ConversationNotFound: BlueCatbirdMlsDSTransferSequencerError("ConversationNotFound", "")
        object NotCurrentSequencer: BlueCatbirdMlsDSTransferSequencerError("NotCurrentSequencer", "")
        object TermStale: BlueCatbirdMlsDSTransferSequencerError("TermStale", "")
        object TransferFailed: BlueCatbirdMlsDSTransferSequencerError("TransferFailed", "")
    }

/**
 * Accept a sequencer role transfer from the current sequencer DS. Transfer sequencer responsibility for a conversation to this DS.
 *
 * Endpoint: blue.catbird.mlsDS.transferSequencer
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.transferSequencer(
input: BlueCatbirdMlsDSTransferSequencerInput): ATProtoResponse<BlueCatbirdMlsDSTransferSequencerOutput> {
    val endpoint = "blue.catbird.mlsDS.transferSequencer"

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
