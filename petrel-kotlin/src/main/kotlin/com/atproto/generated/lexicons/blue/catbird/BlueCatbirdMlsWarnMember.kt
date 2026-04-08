// Lexicon: 1, ID: blue.catbird.mls.warnMember
// Send warning to group member (admin action) Send a warning to a conversation member. Admin-only action. Warning is delivered as a system message and tracked server-side.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsWarnMemberDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.warnMember"
}

@Serializable
    data class BlueCatbirdMlsWarnMemberInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of member to warn        @SerialName("memberDid")
        val memberDid: DID,// Reason for warning        @SerialName("reason")
        val reason: String,// Optional expiration time for warning        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null    )

    @Serializable
    data class BlueCatbirdMlsWarnMemberOutput(
// Unique warning identifier        @SerialName("warningId")
        val warningId: String,// When warning was delivered        @SerialName("deliveredAt")
        val deliveredAt: ATProtocolDate    )

sealed class BlueCatbirdMlsWarnMemberError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsWarnMemberError("ConvoNotFound", "Conversation not found")
        object NotAdmin: BlueCatbirdMlsWarnMemberError("NotAdmin", "Only admins can warn members")
        object TargetNotMember: BlueCatbirdMlsWarnMemberError("TargetNotMember", "Target user is not a member")
        object CannotWarnAdmin: BlueCatbirdMlsWarnMemberError("CannotWarnAdmin", "Cannot warn other admins")
    }

/**
 * Send warning to group member (admin action) Send a warning to a conversation member. Admin-only action. Warning is delivered as a system message and tracked server-side.
 *
 * Endpoint: blue.catbird.mls.warnMember
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.warnMember(
input: BlueCatbirdMlsWarnMemberInput): ATProtoResponse<BlueCatbirdMlsWarnMemberOutput> {
    val endpoint = "blue.catbird.mls.warnMember"

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
