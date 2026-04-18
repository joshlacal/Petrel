// Lexicon: 1, ID: blue.catbird.mlsChat.reportRecoveryFailure
// Report that recovery has been exhausted for a conversation Report that a client has exhausted all recovery attempts for a conversation. Any member may report. When votes from at least ceil(2/3) of the active identity DIDs carry a valid epoch_authenticator within the 1-hour expiry window, the server auto-resets the group (see ADR-002).
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
        val failureType: String? = null,// Hex-encoded epoch_authenticator (RFC 9420 §8.7) for the reporter's current epoch. Optional at the schema layer but REQUIRED for the report to count toward quorum auto-reset. Clients that omit this field will have their report accepted (HTTP 200) with reason="missing_authenticator" but not counted.        @SerialName("epochAuthenticator")
        val epochAuthenticator: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatReportRecoveryFailureOutput(
// Whether the failure report was recorded as a counted quorum vote        @SerialName("recorded")
        val recorded: Boolean,// Whether the quorum threshold was met and an automatic group reset was triggered        @SerialName("autoResetTriggered")
        val autoResetTriggered: Boolean,// Number of distinct identity DIDs whose full active device set has filed valid votes within the expiry window        @SerialName("failureCount")
        val failureCount: Int,// Total number of distinct identity DIDs in the conversation's active member roster        @SerialName("memberCount")
        val memberCount: Int,// Discriminator for why the vote was not counted (if any). Omitted on a successful vote.        @SerialName("reason")
        val reason: String? = null    )

sealed class BlueCatbirdMlsChatReportRecoveryFailureError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatReportRecoveryFailureError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatReportRecoveryFailureError("NotMember", "Caller is not a member of the conversation")
    }

/**
 * Report that recovery has been exhausted for a conversation Report that a client has exhausted all recovery attempts for a conversation. Any member may report. When votes from at least ceil(2/3) of the active identity DIDs carry a valid epoch_authenticator within the 1-hour expiry window, the server auto-resets the group (see ADR-002).
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
