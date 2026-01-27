// Lexicon: 1, ID: com.atproto.sync.getHead
// DEPRECATED - please use com.atproto.sync.getLatestCommit instead
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetHeadDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getHead"
}

@Serializable
    data class ComAtprotoSyncGetHeadParameters(
// The DID of the repo.        @SerialName("did")
        val did: DID    )

    @Serializable
    data class ComAtprotoSyncGetHeadOutput(
        @SerialName("root")
        val root: CID    )

sealed class ComAtprotoSyncGetHeadError(val name: String, val description: String?) {
        object HeadNotFound: ComAtprotoSyncGetHeadError("HeadNotFound", "")
    }

/**
 * DEPRECATED - please use com.atproto.sync.getLatestCommit instead
 *
 * Endpoint: com.atproto.sync.getHead
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getHead(
parameters: ComAtprotoSyncGetHeadParameters): ATProtoResponse<ComAtprotoSyncGetHeadOutput> {
    val endpoint = "com.atproto.sync.getHead"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
