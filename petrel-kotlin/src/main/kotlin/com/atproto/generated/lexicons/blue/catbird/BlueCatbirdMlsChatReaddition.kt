// Lexicon: 1, ID: blue.catbird.mlsChat.readdition
// Request re-addition to a conversation when both Welcome and External Commit have failed. Active members will receive an SSE event and can re-add the user with fresh KeyPackages.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatReadditionDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.readdition"
}

@Serializable
    data class BlueCatbirdMlsChatReadditionInput(
// Conversation ID to rejoin        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsChatReadditionOutput(
// Whether the re-addition request was successfully sent        @SerialName("requested")
        val requested: Boolean,// Number of active members who were notified        @SerialName("activeMembers")
        val activeMembers: Int? = null    )

sealed class BlueCatbirdMlsChatReadditionError(val name: String, val description: String?) {
        object NotFound: BlueCatbirdMlsChatReadditionError("NotFound", "Conversation not found")
        object Unauthorized: BlueCatbirdMlsChatReadditionError("Unauthorized", "Not a member or past member of this conversation")
        object NoActiveMembers: BlueCatbirdMlsChatReadditionError("NoActiveMembers", "No active members available to process re-addition")
    }

/**
 * Request re-addition to a conversation when both Welcome and External Commit have failed. Active members will receive an SSE event and can re-add the user with fresh KeyPackages.
 *
 * Endpoint: blue.catbird.mlsChat.readdition
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.readdition(
input: BlueCatbirdMlsChatReadditionInput): ATProtoResponse<BlueCatbirdMlsChatReadditionOutput> {
    val endpoint = "blue.catbird.mlsChat.readdition"

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
