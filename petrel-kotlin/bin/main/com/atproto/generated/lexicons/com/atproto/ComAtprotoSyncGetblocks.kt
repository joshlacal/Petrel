// Lexicon: 1, ID: com.atproto.sync.getBlocks
// Get data blocks from a given repo, by CID. For example, intermediate MST nodes, or records. Does not require auth; implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetBlocksDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getBlocks"
}

@Serializable
    data class ComAtprotoSyncGetBlocksParameters(
// The DID of the repo.        @SerialName("did")
        val did: DID,        @SerialName("cids")
        val cids: List<CID>    )

    @Serializable
    data class ComAtprotoSyncGetBlocksOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class ComAtprotoSyncGetBlocksError(val name: String, val description: String?) {
        object BlockNotFound: ComAtprotoSyncGetBlocksError("BlockNotFound", "")
        object RepoNotFound: ComAtprotoSyncGetBlocksError("RepoNotFound", "")
        object RepoTakendown: ComAtprotoSyncGetBlocksError("RepoTakendown", "")
        object RepoSuspended: ComAtprotoSyncGetBlocksError("RepoSuspended", "")
        object RepoDeactivated: ComAtprotoSyncGetBlocksError("RepoDeactivated", "")
    }

/**
 * Get data blocks from a given repo, by CID. For example, intermediate MST nodes, or records. Does not require auth; implemented by PDS.
 *
 * Endpoint: com.atproto.sync.getBlocks
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getBlocks(
parameters: ComAtprotoSyncGetBlocksParameters): ATProtoResponse<ComAtprotoSyncGetBlocksOutput> {
    val endpoint = "com.atproto.sync.getBlocks"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/vnd.ipld.car"),
        body = null
    )
}
