// Lexicon: 1, ID: com.atproto.admin.getAccountInfo
// Get details about an account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoAdminGetaccountinfo {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getAccountInfo"

    @Serializable
    data class Parameters(
        @SerialName("did")
        val did: DID    )

        typealias Output = ComAtprotoAdminDefs.Accountview

}

/**
 * Get details about an account.
 *
 * Endpoint: com.atproto.admin.getAccountInfo
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getaccountinfo(
parameters: ComAtprotoAdminGetaccountinfo.Parameters): ATProtoResponse<ComAtprotoAdminGetaccountinfo.Output> {
    val endpoint = "com.atproto.admin.getAccountInfo"

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
