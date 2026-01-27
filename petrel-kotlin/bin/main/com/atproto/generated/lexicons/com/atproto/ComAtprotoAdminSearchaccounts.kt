// Lexicon: 1, ID: com.atproto.admin.searchAccounts
// Get list of accounts that matches your search query.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminSearchAccountsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.searchAccounts"
}

@Serializable
    data class ComAtprotoAdminSearchAccountsParameters(
        @SerialName("email")
        val email: String? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class ComAtprotoAdminSearchAccountsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("accounts")
        val accounts: List<ComAtprotoAdminDefsAccountView>    )

/**
 * Get list of accounts that matches your search query.
 *
 * Endpoint: com.atproto.admin.searchAccounts
 */
suspend fun ATProtoClient.Com.Atproto.Admin.searchAccounts(
parameters: ComAtprotoAdminSearchAccountsParameters): ATProtoResponse<ComAtprotoAdminSearchAccountsOutput> {
    val endpoint = "com.atproto.admin.searchAccounts"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
