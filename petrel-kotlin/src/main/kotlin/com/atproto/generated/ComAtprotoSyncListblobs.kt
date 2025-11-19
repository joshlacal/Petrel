// Lexicon: 1, ID: com.atproto.sync.listBlobs
// List blob CIDs for an account, since some repo revision. Does not require auth; implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncListblobs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.listBlobs"

    @Serializable
    data class Parameters(
// The DID of the repo.        @SerialName("did")
        val did: DID,// Optional revision of the repo to list blobs since.        @SerialName("since")
        val since: String? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("cids")
        val cids: List<CID>    )

    sealed class Error(val name: String, val description: String?) {
        object Reponotfound: Error("RepoNotFound", "")
        object Repotakendown: Error("RepoTakendown", "")
        object Reposuspended: Error("RepoSuspended", "")
        object Repodeactivated: Error("RepoDeactivated", "")
    }

}

/**
 * List blob CIDs for an account, since some repo revision. Does not require auth; implemented by PDS.
 *
 * Endpoint: com.atproto.sync.listBlobs
 */
suspend fun ATProtoClient.Com.Atproto.Sync.listblobs(
parameters: ComAtprotoSyncListblobs.Parameters): ATProtoResponse<ComAtprotoSyncListblobs.Output> {
    val endpoint = "com.atproto.sync.listBlobs"

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
