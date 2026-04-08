// Lexicon: 1, ID: com.atproto.sync.getCheckout
// DEPRECATED - please use com.atproto.sync.getRepo instead
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetCheckoutDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getCheckout"
}

@Serializable
    data class ComAtprotoSyncGetCheckoutParameters(
// The DID of the repo.        @SerialName("did")
        val did: DID    )

    @Serializable
    data class ComAtprotoSyncGetCheckoutOutput(
        @SerialName("data")
        val `data`: ByteArray    )

/**
 * DEPRECATED - please use com.atproto.sync.getRepo instead
 *
 * Endpoint: com.atproto.sync.getCheckout
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getCheckout(
parameters: ComAtprotoSyncGetCheckoutParameters): ATProtoResponse<ComAtprotoSyncGetCheckoutOutput> {
    val endpoint = "com.atproto.sync.getCheckout"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/vnd.ipld.car"),
        body = null
    )
}
