// Lexicon: 1, ID: com.atproto.admin.searchAccounts
// Get list of accounts that matches your search query.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoAdminSearchaccounts {
    const val TYPE_IDENTIFIER = "com.atproto.admin.searchAccounts"

    @Serializable
    data class Parameters(
        @SerialName("email")
        val email: String? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("accounts")
        val accounts: List<ComAtprotoAdminDefs.Accountview>    )

}

/**
 * Get list of accounts that matches your search query.
 *
 * Endpoint: com.atproto.admin.searchAccounts
 */
suspend fun ATProtoClient.Com.Atproto.Admin.searchaccounts(
parameters: ComAtprotoAdminSearchaccounts.Parameters): ATProtoResponse<ComAtprotoAdminSearchaccounts.Output> {
    val endpoint = "com.atproto.admin.searchAccounts"

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
