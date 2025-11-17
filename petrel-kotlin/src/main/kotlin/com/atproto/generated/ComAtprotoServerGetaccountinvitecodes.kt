// Lexicon: 1, ID: com.atproto.server.getAccountInviteCodes
// Get all invite codes for the current account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerGetaccountinvitecodes {
    const val TYPE_IDENTIFIER = "com.atproto.server.getAccountInviteCodes"

    @Serializable
    data class Parameters(
        @SerialName("includeUsed")
        val includeUsed: Boolean? = null,// Controls whether any new 'earned' but not 'created' invites should be created.        @SerialName("createAvailable")
        val createAvailable: Boolean? = null    )

        @Serializable
    data class Output(
        @SerialName("codes")
        val codes: List<ComAtprotoServerDefs.Invitecode>    )

    sealed class Error(val name: String, val description: String?) {
        object Duplicatecreate: Error("DuplicateCreate", "")
    }

}

/**
 * Get all invite codes for the current account. Requires auth.
 *
 * Endpoint: com.atproto.server.getAccountInviteCodes
 */
suspend fun ATProtoClient.Com.Atproto.Server.getaccountinvitecodes(
parameters: ComAtprotoServerGetaccountinvitecodes.Parameters): ATProtoResponse<ComAtprotoServerGetaccountinvitecodes.Output> {
    val endpoint = "com.atproto.server.getAccountInviteCodes"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
