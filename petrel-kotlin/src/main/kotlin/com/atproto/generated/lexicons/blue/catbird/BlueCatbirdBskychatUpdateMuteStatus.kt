// Lexicon: 1, ID: blue.catbird.bskychat.updateMuteStatus
// Update the server-side mute status for a conversation. Used for push notification suppression.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdBskychatUpdateMuteStatusDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.bskychat.updateMuteStatus"
}

@Serializable
    data class BlueCatbirdBskychatUpdateMuteStatusInput(
// The conversation identifier        @SerialName("convoId")
        val convoId: String,// Whether the conversation should be muted        @SerialName("muted")
        val muted: Boolean    )

    @Serializable
    data class BlueCatbirdBskychatUpdateMuteStatusOutput(
        @SerialName("success")
        val success: Boolean    )

/**
 * Update the server-side mute status for a conversation. Used for push notification suppression.
 *
 * Endpoint: blue.catbird.bskychat.updateMuteStatus
 */
suspend fun ATProtoClient.Blue.Catbird.Bskychat.updateMuteStatus(
input: BlueCatbirdBskychatUpdateMuteStatusInput): ATProtoResponse<BlueCatbirdBskychatUpdateMuteStatusOutput> {
    val endpoint = "blue.catbird.bskychat.updateMuteStatus"

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
