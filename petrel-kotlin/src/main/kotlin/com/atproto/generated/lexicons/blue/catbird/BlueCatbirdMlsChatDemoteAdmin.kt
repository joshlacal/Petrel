// Lexicon: 1, ID: blue.catbird.mlsChat.demoteAdmin
// Demote an admin to regular member (admin-only, or self-demotion) Demote an admin to regular member. Caller must be an admin (unless demoting self). Cannot demote the last admin. Server enforces authorization, updates DB, and logs action.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatDemoteAdminDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.demoteAdmin"
}

@Serializable
    data class BlueCatbirdMlsChatDemoteAdminInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of admin to demote (can be self)        @SerialName("targetDid")
        val targetDid: DID    )

    @Serializable
    data class BlueCatbirdMlsChatDemoteAdminOutput(
// Whether demotion succeeded        @SerialName("ok")
        val ok: Boolean    )

sealed class BlueCatbirdMlsChatDemoteAdminError(val name: String, val description: String?) {
        object NotAdmin: BlueCatbirdMlsChatDemoteAdminError("NotAdmin", "Caller is not an admin (unless self-demotion)")
        object NotMember: BlueCatbirdMlsChatDemoteAdminError("NotMember", "Target is not a member")
        object NotAdminTarget: BlueCatbirdMlsChatDemoteAdminError("NotAdminTarget", "Target is not currently an admin")
        object LastAdmin: BlueCatbirdMlsChatDemoteAdminError("LastAdmin", "Cannot demote the last admin in the conversation")
        object ConvoNotFound: BlueCatbirdMlsChatDemoteAdminError("ConvoNotFound", "Conversation not found")
    }

/**
 * Demote an admin to regular member (admin-only, or self-demotion) Demote an admin to regular member. Caller must be an admin (unless demoting self). Cannot demote the last admin. Server enforces authorization, updates DB, and logs action.
 *
 * Endpoint: blue.catbird.mlsChat.demoteAdmin
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.demoteAdmin(
input: BlueCatbirdMlsChatDemoteAdminInput): ATProtoResponse<BlueCatbirdMlsChatDemoteAdminOutput> {
    val endpoint = "blue.catbird.mlsChat.demoteAdmin"

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
