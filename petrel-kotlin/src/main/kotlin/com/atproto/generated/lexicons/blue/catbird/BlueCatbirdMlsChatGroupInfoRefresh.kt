// Lexicon: 1, ID: blue.catbird.mlsChat.groupInfoRefresh
// Request active members to publish fresh GroupInfo for a conversation. Used when a member encounters stale GroupInfo during external commit rejoin. Emits a GroupInfoRefreshRequested SSE event to all active members.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGroupInfoRefreshDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.groupInfoRefresh"
}

@Serializable
    data class BlueCatbirdMlsChatGroupInfoRefreshInput(
// The conversation ID needing fresh GroupInfo        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsChatGroupInfoRefreshOutput(
// Whether the refresh request was emitted        @SerialName("requested")
        val requested: Boolean,// Number of active members notified        @SerialName("activeMembers")
        val activeMembers: Int? = null    )

sealed class BlueCatbirdMlsChatGroupInfoRefreshError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatGroupInfoRefreshError("Unauthorized", "")
        object ConversationNotFound: BlueCatbirdMlsChatGroupInfoRefreshError("ConversationNotFound", "")
    }

/**
 * Request active members to publish fresh GroupInfo for a conversation. Used when a member encounters stale GroupInfo during external commit rejoin. Emits a GroupInfoRefreshRequested SSE event to all active members.
 *
 * Endpoint: blue.catbird.mlsChat.groupInfoRefresh
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.groupInfoRefresh(
input: BlueCatbirdMlsChatGroupInfoRefreshInput): ATProtoResponse<BlueCatbirdMlsChatGroupInfoRefreshOutput> {
    val endpoint = "blue.catbird.mlsChat.groupInfoRefresh"

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
