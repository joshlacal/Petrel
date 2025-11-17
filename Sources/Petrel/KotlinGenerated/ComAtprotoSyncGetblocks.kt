// Lexicon: 1, ID: com.atproto.sync.getBlocks
// Get data blocks from a given repo, by CID. For example, intermediate MST nodes, or records. Does not require auth; implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncGetblocks {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getBlocks"

    @Serializable
    data class Parameters(
// The DID of the repo.        @SerialName("did")
        val did: DID,        @SerialName("cids")
        val cids: List<CID>    )

        @Serializable
    data class Output(
        @SerialName("data")
        val `data`: ByteArray    )

    sealed class Error(val name: String, val description: String?) {
        object Blocknotfound: Error("BlockNotFound", "")
        object Reponotfound: Error("RepoNotFound", "")
        object Repotakendown: Error("RepoTakendown", "")
        object Reposuspended: Error("RepoSuspended", "")
        object Repodeactivated: Error("RepoDeactivated", "")
    }

}

/**
 * Get data blocks from a given repo, by CID. For example, intermediate MST nodes, or records. Does not require auth; implemented by PDS.
 *
 * Endpoint: com.atproto.sync.getBlocks
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getblocks(
parameters: ComAtprotoSyncGetblocks.Parameters): ATProtoResponse<ComAtprotoSyncGetblocks.Output> {
    val endpoint = "com.atproto.sync.getBlocks"

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
