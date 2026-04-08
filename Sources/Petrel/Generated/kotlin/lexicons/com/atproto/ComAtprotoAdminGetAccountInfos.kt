// Lexicon: 1, ID: com.atproto.admin.getAccountInfos
// Get details about some accounts.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminGetAccountInfosDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getAccountInfos"
}

@Serializable
    data class ComAtprotoAdminGetAccountInfosParameters(
        @SerialName("dids")
        val dids: List<DID>    )

    @Serializable
    data class ComAtprotoAdminGetAccountInfosOutput(
        @SerialName("infos")
        val infos: List<ComAtprotoAdminDefsAccountView>    )

/**
 * Get details about some accounts.
 *
 * Endpoint: com.atproto.admin.getAccountInfos
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getAccountInfos(
parameters: ComAtprotoAdminGetAccountInfosParameters): ATProtoResponse<ComAtprotoAdminGetAccountInfosOutput> {
    val endpoint = "com.atproto.admin.getAccountInfos"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
