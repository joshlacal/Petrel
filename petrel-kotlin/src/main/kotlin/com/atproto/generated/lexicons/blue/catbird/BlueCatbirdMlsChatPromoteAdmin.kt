// Lexicon: 1, ID: blue.catbird.mlsChat.promoteAdmin
// Promote a member to admin status (admin-only operation) Promote a conversation member to admin. Caller must be an existing admin. Server enforces authorization, then updates DB and logs action. Caller should also send an encrypted adminRoster update via sendMessage.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatPromoteAdminDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.promoteAdmin"
}

@Serializable
    data class BlueCatbirdMlsChatPromoteAdminInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of member to promote to admin        @SerialName("targetDid")
        val targetDid: DID    )

    @Serializable
    data class BlueCatbirdMlsChatPromoteAdminOutput(
// Whether promotion succeeded        @SerialName("ok")
        val ok: Boolean,// Timestamp when member was promoted        @SerialName("promotedAt")
        val promotedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatPromoteAdminError(val name: String, val description: String?) {
        object NotAdmin: BlueCatbirdMlsChatPromoteAdminError("NotAdmin", "Caller is not an admin of this conversation")
        object NotMember: BlueCatbirdMlsChatPromoteAdminError("NotMember", "Target is not a member of this conversation")
        object AlreadyAdmin: BlueCatbirdMlsChatPromoteAdminError("AlreadyAdmin", "Target is already an admin")
        object ConvoNotFound: BlueCatbirdMlsChatPromoteAdminError("ConvoNotFound", "Conversation not found")
    }

/**
 * Promote a member to admin status (admin-only operation) Promote a conversation member to admin. Caller must be an existing admin. Server enforces authorization, then updates DB and logs action. Caller should also send an encrypted adminRoster update via sendMessage.
 *
 * Endpoint: blue.catbird.mlsChat.promoteAdmin
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.promoteAdmin(
input: BlueCatbirdMlsChatPromoteAdminInput): ATProtoResponse<BlueCatbirdMlsChatPromoteAdminOutput> {
    val endpoint = "blue.catbird.mlsChat.promoteAdmin"

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
