// Lexicon: 1, ID: blue.catbird.mlsDS.getConvoDigest
// Get a cryptographic digest of all messages in a conversation for reconciliation. Compute and return a SHA-256 digest over all messages in a conversation, along with sequencer state.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSGetConvoDigestDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.getConvoDigest"
}

@Serializable
    data class BlueCatbirdMlsDSGetConvoDigestParameters(
// Conversation ID        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsDSGetConvoDigestOutput(
// Conversation ID        @SerialName("convoId")
        val convoId: String,// DID of the current sequencer DS        @SerialName("sequencerDsDid")
        val sequencerDsDid: String,// Current sequencer term        @SerialName("sequencerTerm")
        val sequencerTerm: Int,// Current MLS epoch        @SerialName("epoch")
        val epoch: Int,// Highest sequence number        @SerialName("lastSeq")
        val lastSeq: Int,// Total number of events/messages        @SerialName("eventCount")
        val eventCount: Int,// Hex-encoded SHA-256 digest over all messages        @SerialName("digestSha256")
        val digestSha256: String,// Timestamp when the digest was generated        @SerialName("generatedAt")
        val generatedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsDSGetConvoDigestError(val name: String, val description: String?) {
        object ConversationNotFound: BlueCatbirdMlsDSGetConvoDigestError("ConversationNotFound", "")
        object NotAuthorized: BlueCatbirdMlsDSGetConvoDigestError("NotAuthorized", "")
    }

/**
 * Get a cryptographic digest of all messages in a conversation for reconciliation. Compute and return a SHA-256 digest over all messages in a conversation, along with sequencer state.
 *
 * Endpoint: blue.catbird.mlsDS.getConvoDigest
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.getConvoDigest(
parameters: BlueCatbirdMlsDSGetConvoDigestParameters): ATProtoResponse<BlueCatbirdMlsDSGetConvoDigestOutput> {
    val endpoint = "blue.catbird.mlsDS.getConvoDigest"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
