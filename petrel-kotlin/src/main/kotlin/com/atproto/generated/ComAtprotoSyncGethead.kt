// Lexicon: 1, ID: com.atproto.sync.getHead
// DEPRECATED - please use com.atproto.sync.getLatestCommit instead
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncGethead {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getHead"

    @Serializable
    data class Parameters(
// The DID of the repo.        @SerialName("did")
        val did: DID    )

        @Serializable
    data class Output(
        @SerialName("root")
        val root: CID    )

    sealed class Error(val name: String, val description: String?) {
        object Headnotfound: Error("HeadNotFound", "")
    }

}

/**
 * DEPRECATED - please use com.atproto.sync.getLatestCommit instead
 *
 * Endpoint: com.atproto.sync.getHead
 */
suspend fun ATProtoClient.Com.Atproto.Sync.gethead(
parameters: ComAtprotoSyncGethead.Parameters): ATProtoResponse<ComAtprotoSyncGethead.Output> {
    val endpoint = "com.atproto.sync.getHead"

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
