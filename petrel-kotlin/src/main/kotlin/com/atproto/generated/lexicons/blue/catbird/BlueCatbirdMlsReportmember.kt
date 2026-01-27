// Lexicon: 1, ID: blue.catbird.mls.reportMember
// Report a member for moderation (end-to-end encrypted) Submit an encrypted report about a conversation member to admins. Report content is E2EE and only admins can decrypt. Server stores metadata and routes to admins. Any member can report; cannot report self.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsReportMemberDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.reportMember"
}

@Serializable
    data class BlueCatbirdMlsReportMemberInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of member being reported        @SerialName("reportedDid")
        val reportedDid: DID,// Report category (required for App Store compliance). Visible to server for statistics, but details are encrypted.        @SerialName("category")
        val category: String,// Encrypted report blob containing detailed reason, context, and optional evidence (message IDs, screenshots). Only admins can decrypt using MLS group key or admin-specific encryption.        @SerialName("encryptedContent")
        val encryptedContent: ByteArray,// Optional list of message IDs being reported (for reference, not encrypted). Max 20 messages.        @SerialName("messageIds")
        val messageIds: List<String>? = null    )

    @Serializable
    data class BlueCatbirdMlsReportMemberOutput(
// Unique report identifier        @SerialName("reportId")
        val reportId: String,// When report was submitted        @SerialName("submittedAt")
        val submittedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsReportMemberError(val name: String, val description: String?) {
        object NotMember: BlueCatbirdMlsReportMemberError("NotMember", "Caller is not a member")
        object TargetNotMember: BlueCatbirdMlsReportMemberError("TargetNotMember", "Reported user is not a member")
        object CannotReportSelf: BlueCatbirdMlsReportMemberError("CannotReportSelf", "Cannot report yourself")
        object ConvoNotFound: BlueCatbirdMlsReportMemberError("ConvoNotFound", "Conversation not found")
    }

/**
 * Report a member for moderation (end-to-end encrypted) Submit an encrypted report about a conversation member to admins. Report content is E2EE and only admins can decrypt. Server stores metadata and routes to admins. Any member can report; cannot report self.
 *
 * Endpoint: blue.catbird.mls.reportMember
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.reportMember(
input: BlueCatbirdMlsReportMemberInput): ATProtoResponse<BlueCatbirdMlsReportMemberOutput> {
    val endpoint = "blue.catbird.mls.reportMember"

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
