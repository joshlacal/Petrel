// Lexicon: 1, ID: blue.catbird.mlsChat.requestFailover
// Request sequencer failover for a conversation (spec §8.8) Request sequencer failover for a conversation. Called when >= 3 consecutive send timeouts occur over >= 2 minutes.
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
// Whether the failover request was accepted        @SerialName("success")
        val success: Boolean    )

sealed class BlueCatbirdMlsChatRequestFailoverError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatRequestFailoverError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatRequestFailoverError("NotMember", "Caller is not a member of the conversation")
    }

/**
 * Request sequencer failover for a conversation (spec §8.8) Request sequencer failover for a conversation. Called when >= 3 consecutive send timeouts occur over >= 2 minutes.
 *
 * Endpoint: blue.catbird.mlsChat.requestFailover
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.requestFailover(
input: BlueCatbirdMlsChatRequestFailoverInput): ATProtoResponse<BlueCatbirdMlsChatRequestFailoverOutput> {
    val endpoint = "blue.catbird.mlsChat.requestFailover"

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
