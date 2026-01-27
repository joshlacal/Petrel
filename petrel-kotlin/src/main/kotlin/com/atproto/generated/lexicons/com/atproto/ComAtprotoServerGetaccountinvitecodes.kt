// Lexicon: 1, ID: com.atproto.server.getAccountInviteCodes
// Get all invite codes for the current account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerGetAccountInviteCodesDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.getAccountInviteCodes"
}

@Serializable
    data class ComAtprotoServerGetAccountInviteCodesParameters(
        @SerialName("includeUsed")
        val includeUsed: Boolean? = null,// Controls whether any new 'earned' but not 'created' invites should be created.        @SerialName("createAvailable")
        val createAvailable: Boolean? = null    )

    @Serializable
    data class ComAtprotoServerGetAccountInviteCodesOutput(
        @SerialName("codes")
        val codes: List<ComAtprotoServerDefsInviteCode>    )

sealed class ComAtprotoServerGetAccountInviteCodesError(val name: String, val description: String?) {
        object DuplicateCreate: ComAtprotoServerGetAccountInviteCodesError("DuplicateCreate", "")
    }

/**
 * Get all invite codes for the current account. Requires auth.
 *
 * Endpoint: com.atproto.server.getAccountInviteCodes
 */
suspend fun ATProtoClient.Com.Atproto.Server.getAccountInviteCodes(
parameters: ComAtprotoServerGetAccountInviteCodesParameters): ATProtoResponse<ComAtprotoServerGetAccountInviteCodesOutput> {
    val endpoint = "com.atproto.server.getAccountInviteCodes"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
