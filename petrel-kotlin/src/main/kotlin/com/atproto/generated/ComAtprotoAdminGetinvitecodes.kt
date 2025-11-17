// Lexicon: 1, ID: com.atproto.admin.getInviteCodes
// Get an admin view of invite codes.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoAdminGetinvitecodes {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getInviteCodes"

    @Serializable
    data class Parameters(
        @SerialName("sort")
        val sort: String? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("codes")
        val codes: List<ComAtprotoServerDefs.Invitecode>    )

}

/**
 * Get an admin view of invite codes.
 *
 * Endpoint: com.atproto.admin.getInviteCodes
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getinvitecodes(
parameters: ComAtprotoAdminGetinvitecodes.Parameters): ATProtoResponse<ComAtprotoAdminGetinvitecodes.Output> {
    val endpoint = "com.atproto.admin.getInviteCodes"

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
