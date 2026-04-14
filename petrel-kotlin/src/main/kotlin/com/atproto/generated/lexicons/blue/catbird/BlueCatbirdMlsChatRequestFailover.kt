// Lexicon: 1, ID: blue.catbird.mlsChat.requestFailover
// Request sequencer failover when the current sequencer is unreachable Request sequencer failover for a conversation. Only members may call this. The handler health-checks the current sequencer before allowing the takeover. Returns CONFLICT if the current sequencer is still healthy.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatRequestFailoverDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.requestFailover"
}

@Serializable
    data class BlueCatbirdMlsChatRequestFailoverInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsChatRequestFailoverOutput(
// DID of the new sequencer that assumed the role        @SerialName("newSequencerDid")
        val newSequencerDid: DID,// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Current MLS epoch after failover        @SerialName("epoch")
        val epoch: Int,// New sequencer term number        @SerialName("sequencerTerm")
        val sequencerTerm: Int    )

sealed class BlueCatbirdMlsChatRequestFailoverError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatRequestFailoverError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatRequestFailoverError("NotMember", "Caller is not a member of the conversation")
        object SequencerHealthy: BlueCatbirdMlsChatRequestFailoverError("SequencerHealthy", "Current sequencer is still healthy, failover denied")
    }

/**
 * Request sequencer failover when the current sequencer is unreachable Request sequencer failover for a conversation. Only members may call this. The handler health-checks the current sequencer before allowing the takeover. Returns CONFLICT if the current sequencer is still healthy.
 *
 * Endpoint: blue.catbird.mlsChat.requestFailover
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.requestFailover(
input: BlueCatbirdMlsChatRequestFailoverInput): ATProtoResponse<BlueCatbirdMlsChatRequestFailoverOutput> {
    val endpoint = "blue.catbird.mlsChat.requestFailover"

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
