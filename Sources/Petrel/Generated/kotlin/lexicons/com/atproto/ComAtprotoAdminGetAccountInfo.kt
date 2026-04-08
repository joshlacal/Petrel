// Lexicon: 1, ID: com.atproto.admin.getAccountInfo
// Get details about an account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminGetAccountInfoDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getAccountInfo"
}

@Serializable
    data class ComAtprotoAdminGetAccountInfoParameters(
        @SerialName("did")
        val did: DID    )

    typealias ComAtprotoAdminGetAccountInfoOutput = ComAtprotoAdminDefsAccountView

/**
 * Get details about an account.
 *
 * Endpoint: com.atproto.admin.getAccountInfo
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getAccountInfo(
parameters: ComAtprotoAdminGetAccountInfoParameters): ATProtoResponse<ComAtprotoAdminGetAccountInfoOutput> {
    val endpoint = "com.atproto.admin.getAccountInfo"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
