// Lexicon: 1, ID: com.atproto.sync.getCheckout
// DEPRECATED - please use com.atproto.sync.getRepo instead
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncGetcheckout {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getCheckout"

    @Serializable
    data class Parameters(
// The DID of the repo.        @SerialName("did")
        val did: DID    )

        @Serializable
    data class Output(
        @SerialName("data")
        val `data`: ByteArray    )

}

/**
 * DEPRECATED - please use com.atproto.sync.getRepo instead
 *
 * Endpoint: com.atproto.sync.getCheckout
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getcheckout(
parameters: ComAtprotoSyncGetcheckout.Parameters): ATProtoResponse<ComAtprotoSyncGetcheckout.Output> {
    val endpoint = "com.atproto.sync.getCheckout"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/vnd.ipld.car"),
        body = null
    )
}
