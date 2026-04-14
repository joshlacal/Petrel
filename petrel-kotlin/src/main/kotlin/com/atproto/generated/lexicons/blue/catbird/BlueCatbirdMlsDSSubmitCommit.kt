// Lexicon: 1, ID: blue.catbird.mlsDS.submitCommit
// Submit a commit for CAS sequencing on the sequencer DS. Submit an MLS commit for epoch ordering via compare-and-swap. The sequencer assigns the epoch and returns a receipt.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSSubmitCommitDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.submitCommit"
}

@Serializable
    data class BlueCatbirdMlsDSSubmitCommitInput(
// Conversation ID        @SerialName("convoId")
        val convoId: String,// DID of the submitting delivery service        @SerialName("senderDsDid")
        val senderDsDid: String,// Current expected epoch        @SerialName("epoch")
        val epoch: Int,// Proposed next epoch        @SerialName("proposedEpoch")
        val proposedEpoch: Int,// Serialized MLS commit        @SerialName("commitData")
        val commitData: Bytes,// Current sequencer term for CAS validation        @SerialName("sequencerTerm")
        val sequencerTerm: Int    )

    @Serializable
    data class BlueCatbirdMlsDSSubmitCommitOutput(
// Whether the commit was accepted        @SerialName("accepted")
        val accepted: Boolean,// Epoch assigned by the sequencer        @SerialName("assignedEpoch")
        val assignedEpoch: Int,// Current sequencer term        @SerialName("sequencerTerm")
        val sequencerTerm: Int,// Sequencer receipt for the commit        @SerialName("receipt")
        val receipt: String? = null    )

sealed class BlueCatbirdMlsDSSubmitCommitError(val name: String, val description: String?) {
        object ConversationNotFound: BlueCatbirdMlsDSSubmitCommitError("ConversationNotFound", "")
        object NotSequencer: BlueCatbirdMlsDSSubmitCommitError("NotSequencer", "")
        object TermStale: BlueCatbirdMlsDSSubmitCommitError("TermStale", "")
        object CommitConflict: BlueCatbirdMlsDSSubmitCommitError("CommitConflict", "")
    }

/**
 * Submit a commit for CAS sequencing on the sequencer DS. Submit an MLS commit for epoch ordering via compare-and-swap. The sequencer assigns the epoch and returns a receipt.
 *
 * Endpoint: blue.catbird.mlsDS.submitCommit
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.submitCommit(
input: BlueCatbirdMlsDSSubmitCommitInput): ATProtoResponse<BlueCatbirdMlsDSSubmitCommitOutput> {
    val endpoint = "blue.catbird.mlsDS.submitCommit"

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
