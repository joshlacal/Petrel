// Lexicon: 1, ID: blue.catbird.mls.groupInfoRefresh
// Request active members to publish fresh GroupInfo for a conversation. Used when a member encounters stale GroupInfo during external commit rejoin. Emits a GroupInfoRefreshRequested SSE event to all active members.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGroupInfoRefreshDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.groupInfoRefresh"
}

@Serializable
    data class BlueCatbirdMlsGroupInfoRefreshInput(
// The conversation ID needing fresh GroupInfo        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsGroupInfoRefreshOutput(
// Whether the refresh request was emitted        @SerialName("requested")
        val requested: Boolean,// Number of active members notified        @SerialName("activeMembers")
        val activeMembers: Int? = null    )

sealed class BlueCatbirdMlsGroupInfoRefreshError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsGroupInfoRefreshError("Unauthorized", "")
        object ConversationNotFound: BlueCatbirdMlsGroupInfoRefreshError("ConversationNotFound", "")
    }

/**
 * Request active members to publish fresh GroupInfo for a conversation. Used when a member encounters stale GroupInfo during external commit rejoin. Emits a GroupInfoRefreshRequested SSE event to all active members.
 *
 * Endpoint: blue.catbird.mls.groupInfoRefresh
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.groupInfoRefresh(
input: BlueCatbirdMlsGroupInfoRefreshInput): ATProtoResponse<BlueCatbirdMlsGroupInfoRefreshOutput> {
    val endpoint = "blue.catbird.mls.groupInfoRefresh"

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
