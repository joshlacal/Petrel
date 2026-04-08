// Lexicon: 1, ID: blue.catbird.mlsChat.reportSpam
// Report a conversation member for spam
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatReportSpamDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.reportSpam"
}

@Serializable
    data class BlueCatbirdMlsChatReportSpamInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of the member being reported for spam        @SerialName("reportedDid")
        val reportedDid: DID,// Optional reason for the report        @SerialName("reason")
        val reason: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatReportSpamOutput(
// Unique identifier for the spam report        @SerialName("id")
        val id: String,// When the report was created        @SerialName("createdAt")
        val createdAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatReportSpamError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatReportSpamError("Unauthorized", "Authentication required")
        object NotFound: BlueCatbirdMlsChatReportSpamError("NotFound", "Conversation or member not found")
        object DuplicateReport: BlueCatbirdMlsChatReportSpamError("DuplicateReport", "A report for this member in this conversation already exists")
    }

/**
 * Report a conversation member for spam
 *
 * Endpoint: blue.catbird.mlsChat.reportSpam
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.reportSpam(
input: BlueCatbirdMlsChatReportSpamInput): ATProtoResponse<BlueCatbirdMlsChatReportSpamOutput> {
    val endpoint = "blue.catbird.mlsChat.reportSpam"

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
