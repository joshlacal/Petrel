// Lexicon: 1, ID: blue.catbird.mlsChat.updateCursor
// Update the read cursor position for a conversation
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatUpdateCursorDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.updateCursor"
}

@Serializable
    data class BlueCatbirdMlsChatUpdateCursorInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Opaque cursor string marking the read position        @SerialName("cursor")
        val cursor: String    )

    @Serializable
    data class BlueCatbirdMlsChatUpdateCursorOutput(
// Server timestamp when the cursor was updated        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatUpdateCursorError(val name: String, val description: String?) {
        object AuthRequired: BlueCatbirdMlsChatUpdateCursorError("AuthRequired", "Authentication required")
        object Forbidden: BlueCatbirdMlsChatUpdateCursorError("Forbidden", "User is not a member of the conversation")
        object InvalidRequest: BlueCatbirdMlsChatUpdateCursorError("InvalidRequest", "Invalid cursor or conversation ID")
    }

/**
 * Update the read cursor position for a conversation
 *
 * Endpoint: blue.catbird.mlsChat.updateCursor
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.updateCursor(
input: BlueCatbirdMlsChatUpdateCursorInput): ATProtoResponse<BlueCatbirdMlsChatUpdateCursorOutput> {
    val endpoint = "blue.catbird.mlsChat.updateCursor"

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
