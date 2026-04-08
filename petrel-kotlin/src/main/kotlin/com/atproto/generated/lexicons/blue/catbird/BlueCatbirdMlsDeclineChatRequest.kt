// Lexicon: 1, ID: blue.catbird.mls.declineChatRequest
// Decline a chat request
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDeclineChatRequestDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.declineChatRequest"
}

@Serializable
    data class BlueCatbirdMlsDeclineChatRequestInput(
// ID of the request to decline        @SerialName("requestId")
        val requestId: String,// Optional reason for declining (for reporting)        @SerialName("reportReason")
        val reportReason: String? = null,// Additional details for report        @SerialName("reportDetails")
        val reportDetails: String? = null    )

    @Serializable
    data class BlueCatbirdMlsDeclineChatRequestOutput(
        @SerialName("success")
        val success: Boolean    )

sealed class BlueCatbirdMlsDeclineChatRequestError(val name: String, val description: String?) {
        object RequestNotFound: BlueCatbirdMlsDeclineChatRequestError("RequestNotFound", "")
    }

/**
 * Decline a chat request
 *
 * Endpoint: blue.catbird.mls.declineChatRequest
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.declineChatRequest(
input: BlueCatbirdMlsDeclineChatRequestInput): ATProtoResponse<BlueCatbirdMlsDeclineChatRequestOutput> {
    val endpoint = "blue.catbird.mls.declineChatRequest"

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
