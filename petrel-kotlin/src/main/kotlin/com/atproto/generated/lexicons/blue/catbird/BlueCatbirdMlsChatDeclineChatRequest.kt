// Lexicon: 1, ID: blue.catbird.mlsChat.declineChatRequest
// Decline a chat request
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatDeclineChatRequestDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.declineChatRequest"
}

@Serializable
    data class BlueCatbirdMlsChatDeclineChatRequestInput(
// ID of the request to decline        @SerialName("requestId")
        val requestId: String,// Optional reason for declining (for reporting)        @SerialName("reportReason")
        val reportReason: String? = null,// Additional details for report        @SerialName("reportDetails")
        val reportDetails: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatDeclineChatRequestOutput(
        @SerialName("success")
        val success: Boolean    )

sealed class BlueCatbirdMlsChatDeclineChatRequestError(val name: String, val description: String?) {
        object RequestNotFound: BlueCatbirdMlsChatDeclineChatRequestError("RequestNotFound", "")
    }

/**
 * Decline a chat request
 *
 * Endpoint: blue.catbird.mlsChat.declineChatRequest
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.declineChatRequest(
input: BlueCatbirdMlsChatDeclineChatRequestInput): ATProtoResponse<BlueCatbirdMlsChatDeclineChatRequestOutput> {
    val endpoint = "blue.catbird.mlsChat.declineChatRequest"

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
