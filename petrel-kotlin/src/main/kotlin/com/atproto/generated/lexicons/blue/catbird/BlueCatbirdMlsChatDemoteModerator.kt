// Lexicon: 1, ID: blue.catbird.mlsChat.demoteModerator
// Demote a moderator to regular member (admin-only, or self-demotion) Demote a moderator to regular member. Caller must be an admin (unless demoting self). Server enforces authorization, updates DB, and logs action.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatDemoteModeratorDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.demoteModerator"
}

@Serializable
    data class BlueCatbirdMlsChatDemoteModeratorInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of moderator to demote (can be self)        @SerialName("targetDid")
        val targetDid: DID    )

    @Serializable
    data class BlueCatbirdMlsChatDemoteModeratorOutput(
// Whether demotion succeeded        @SerialName("ok")
        val ok: Boolean    )

sealed class BlueCatbirdMlsChatDemoteModeratorError(val name: String, val description: String?) {
        object NotAdmin: BlueCatbirdMlsChatDemoteModeratorError("NotAdmin", "Caller is not an admin (unless self-demotion)")
        object NotMember: BlueCatbirdMlsChatDemoteModeratorError("NotMember", "Target is not a member")
        object NotModerator: BlueCatbirdMlsChatDemoteModeratorError("NotModerator", "Target is not currently a moderator")
        object ConvoNotFound: BlueCatbirdMlsChatDemoteModeratorError("ConvoNotFound", "Conversation not found")
    }

/**
 * Demote a moderator to regular member (admin-only, or self-demotion) Demote a moderator to regular member. Caller must be an admin (unless demoting self). Server enforces authorization, updates DB, and logs action.
 *
 * Endpoint: blue.catbird.mlsChat.demoteModerator
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.demoteModerator(
input: BlueCatbirdMlsChatDemoteModeratorInput): ATProtoResponse<BlueCatbirdMlsChatDemoteModeratorOutput> {
    val endpoint = "blue.catbird.mlsChat.demoteModerator"

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
