// Lexicon: 1, ID: blue.catbird.mlsChat.reportRecoveryFailure
// Report that recovery has been exhausted for a conversation (spec §8.6) Report that recovery has been exhausted for a conversation. Server uses these reports for quorum-based auto-reset (>=50% of members must report within 1 hour for auto-reset to trigger).
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
        val convoId: String,// Type of failure (default: external_commit_exhausted)        @SerialName("failureType")
        val failureType: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatReportRecoveryFailureOutput(
// Whether the failure report was recorded        @SerialName("recorded")
        val recorded: Boolean,// Whether quorum-based auto-reset was triggered        @SerialName("autoResetTriggered")
        val autoResetTriggered: Boolean    )

sealed class BlueCatbirdMlsChatReportRecoveryFailureError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatReportRecoveryFailureError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatReportRecoveryFailureError("NotMember", "Caller is not a member of the conversation")
    }

/**
 * Report that recovery has been exhausted for a conversation (spec §8.6) Report that recovery has been exhausted for a conversation. Server uses these reports for quorum-based auto-reset (>=50% of members must report within 1 hour for auto-reset to trigger).
 *
 * Endpoint: blue.catbird.mlsChat.reportRecoveryFailure
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.reportRecoveryFailure(
input: BlueCatbirdMlsChatReportRecoveryFailureInput): ATProtoResponse<BlueCatbirdMlsChatReportRecoveryFailureOutput> {
    val endpoint = "blue.catbird.mlsChat.reportRecoveryFailure"

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
