// Lexicon: 1, ID: com.atproto.admin.getInviteCodes
// Get an admin view of invite codes.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminGetInviteCodesDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getInviteCodes"
}

@Serializable
    data class ComAtprotoAdminGetInviteCodesParameters(
        @SerialName("sort")
        val sort: String? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ComAtprotoAdminGetInviteCodesOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("codes")
        val codes: List<ComAtprotoServerDefsInviteCode>    )

/**
 * Get an admin view of invite codes.
 *
 * Endpoint: com.atproto.admin.getInviteCodes
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getInviteCodes(
parameters: ComAtprotoAdminGetInviteCodesParameters): ATProtoResponse<ComAtprotoAdminGetInviteCodesOutput> {
    val endpoint = "com.atproto.admin.getInviteCodes"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
