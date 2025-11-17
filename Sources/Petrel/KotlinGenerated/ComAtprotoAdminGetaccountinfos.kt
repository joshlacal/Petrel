// Lexicon: 1, ID: com.atproto.admin.getAccountInfos
// Get details about some accounts.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoAdminGetaccountinfos {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getAccountInfos"

    @Serializable
    data class Parameters(
        @SerialName("dids")
        val dids: List<DID>    )

        @Serializable
    data class Output(
        @SerialName("infos")
        val infos: List<ComAtprotoAdminDefs.Accountview>    )

}

/**
 * Get details about some accounts.
 *
 * Endpoint: com.atproto.admin.getAccountInfos
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getaccountinfos(
parameters: ComAtprotoAdminGetaccountinfos.Parameters): ATProtoResponse<ComAtprotoAdminGetaccountinfos.Output> {
    val endpoint = "com.atproto.admin.getAccountInfos"

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
