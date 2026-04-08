// Lexicon: 1, ID: blue.catbird.mlsChat.warnMember
// Send warning to group member (admin action) Send a warning to a conversation member. Admin-only action. Warning is delivered as a system message and tracked server-side.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatWarnMemberDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.warnMember"
}

@Serializable
    data class BlueCatbirdMlsChatWarnMemberInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of member to warn        @SerialName("memberDid")
        val memberDid: DID,// Reason for warning        @SerialName("reason")
        val reason: String,// Optional expiration time for warning        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null    )

    @Serializable
    data class BlueCatbirdMlsChatWarnMemberOutput(
// Unique warning identifier        @SerialName("warningId")
        val warningId: String,// When warning was delivered        @SerialName("deliveredAt")
        val deliveredAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatWarnMemberError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatWarnMemberError("ConvoNotFound", "Conversation not found")
        object NotAdmin: BlueCatbirdMlsChatWarnMemberError("NotAdmin", "Only admins can warn members")
        object TargetNotMember: BlueCatbirdMlsChatWarnMemberError("TargetNotMember", "Target user is not a member")
        object CannotWarnAdmin: BlueCatbirdMlsChatWarnMemberError("CannotWarnAdmin", "Cannot warn other admins")
    }

/**
 * Send warning to group member (admin action) Send a warning to a conversation member. Admin-only action. Warning is delivered as a system message and tracked server-side.
 *
 * Endpoint: blue.catbird.mlsChat.warnMember
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.warnMember(
input: BlueCatbirdMlsChatWarnMemberInput): ATProtoResponse<BlueCatbirdMlsChatWarnMemberOutput> {
    val endpoint = "blue.catbird.mlsChat.warnMember"

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
