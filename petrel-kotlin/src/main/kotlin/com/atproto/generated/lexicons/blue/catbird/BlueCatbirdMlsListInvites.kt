// Lexicon: 1, ID: blue.catbird.mls.listInvites
// List all invite links for a conversation Query to fetch all invites for a conversation. Only admins can list invites.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsListInvitesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.listInvites"
}

@Serializable
    data class BlueCatbirdMlsListInvitesParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Whether to include revoked invites in the results        @SerialName("includeRevoked")
        val includeRevoked: Boolean? = null    )

    @Serializable
    data class BlueCatbirdMlsListInvitesOutput(
// List of invites for this conversation        @SerialName("invites")
        val invites: List<BlueCatbirdMlsCreateInviteInviteView>    )

sealed class BlueCatbirdMlsListInvitesError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsListInvitesError("Unauthorized", "Caller is not an admin of this conversation")
        object ConvoNotFound: BlueCatbirdMlsListInvitesError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsListInvitesError("NotMember", "Caller is not a member of this conversation")
    }

/**
 * List all invite links for a conversation Query to fetch all invites for a conversation. Only admins can list invites.
 *
 * Endpoint: blue.catbird.mls.listInvites
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.listInvites(
parameters: BlueCatbirdMlsListInvitesParameters): ATProtoResponse<BlueCatbirdMlsListInvitesOutput> {
    val endpoint = "blue.catbird.mls.listInvites"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
