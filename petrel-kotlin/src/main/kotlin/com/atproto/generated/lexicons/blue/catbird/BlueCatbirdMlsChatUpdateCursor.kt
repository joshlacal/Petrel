// Lexicon: 1, ID: blue.catbird.mlsChat.updateCursor
// Update the read cursor position for a conversation Update the read cursor for a conversation to track the last-read position.
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
        val convoId: String,// Opaque cursor value representing the read position (e.g., seq number as string)        @SerialName("cursor")
        val cursor: String    )

    @Serializable
    data class BlueCatbirdMlsChatUpdateCursorOutput(
// Timestamp when the cursor was updated        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatUpdateCursorError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatUpdateCursorError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatUpdateCursorError("NotMember", "Caller is not a member of the conversation")
        object InvalidCursor: BlueCatbirdMlsChatUpdateCursorError("InvalidCursor", "The provided cursor value is invalid")
    }

/**
 * Update the read cursor position for a conversation Update the read cursor for a conversation to track the last-read position.
 *
 * Endpoint: blue.catbird.mlsChat.updateCursor
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.updateCursor(
input: BlueCatbirdMlsChatUpdateCursorInput): ATProtoResponse<BlueCatbirdMlsChatUpdateCursorOutput> {
    val endpoint = "blue.catbird.mlsChat.updateCursor"

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
