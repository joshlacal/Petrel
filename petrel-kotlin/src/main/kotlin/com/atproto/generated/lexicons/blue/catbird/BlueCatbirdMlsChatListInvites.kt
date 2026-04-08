// Lexicon: 1, ID: blue.catbird.mlsChat.listInvites
// List all invite links for a conversation Query to fetch all invites for a conversation. Only admins can list invites.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatListInvitesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.listInvites"
}

@Serializable
    data class BlueCatbirdMlsChatListInvitesParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Whether to include revoked invites in the results        @SerialName("includeRevoked")
        val includeRevoked: Boolean? = null    )

    @Serializable
    data class BlueCatbirdMlsChatListInvitesOutput(
// List of invites for this conversation        @SerialName("invites")
        val invites: List<BlueCatbirdMlsChatCreateInviteInviteView>    )

sealed class BlueCatbirdMlsChatListInvitesError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatListInvitesError("Unauthorized", "Caller is not an admin of this conversation")
        object ConvoNotFound: BlueCatbirdMlsChatListInvitesError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatListInvitesError("NotMember", "Caller is not a member of this conversation")
    }

/**
 * List all invite links for a conversation Query to fetch all invites for a conversation. Only admins can list invites.
 *
 * Endpoint: blue.catbird.mlsChat.listInvites
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.listInvites(
parameters: BlueCatbirdMlsChatListInvitesParameters): ATProtoResponse<BlueCatbirdMlsChatListInvitesOutput> {
    val endpoint = "blue.catbird.mlsChat.listInvites"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
