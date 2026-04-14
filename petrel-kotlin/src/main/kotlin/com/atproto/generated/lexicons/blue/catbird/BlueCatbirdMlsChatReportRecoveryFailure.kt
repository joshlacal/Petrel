// Lexicon: 1, ID: blue.catbird.mlsChat.reportRecoveryFailure
// Report that recovery has been exhausted for a conversation Report that a client has exhausted all recovery attempts for a conversation. Any member may report. When >=50% of active members have reported within a 1-hour window, the server auto-resets the group.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatReportRecoveryFailureDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.reportRecoveryFailure"
}

@Serializable
    data class BlueCatbirdMlsChatReportRecoveryFailureInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Type of failure that was exhausted        @SerialName("failureType")
        val failureType: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatReportRecoveryFailureOutput(
// Whether the failure report was recorded        @SerialName("recorded")
        val recorded: Boolean,// Whether the quorum threshold was met and an automatic group reset was triggered        @SerialName("autoResetTriggered")
        val autoResetTriggered: Boolean,// Number of members who have reported failures within the expiry window        @SerialName("failureCount")
        val failureCount: Int,// Total number of active members in the conversation        @SerialName("memberCount")
        val memberCount: Int    )

sealed class BlueCatbirdMlsChatReportRecoveryFailureError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatReportRecoveryFailureError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatReportRecoveryFailureError("NotMember", "Caller is not a member of the conversation")
    }

/**
 * Report that recovery has been exhausted for a conversation Report that a client has exhausted all recovery attempts for a conversation. Any member may report. When >=50% of active members have reported within a 1-hour window, the server auto-resets the group.
 *
 * Endpoint: blue.catbird.mlsChat.reportRecoveryFailure
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.reportRecoveryFailure(
input: BlueCatbirdMlsChatReportRecoveryFailureInput): ATProtoResponse<BlueCatbirdMlsChatReportRecoveryFailureOutput> {
    val endpoint = "blue.catbird.mlsChat.reportRecoveryFailure"

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
