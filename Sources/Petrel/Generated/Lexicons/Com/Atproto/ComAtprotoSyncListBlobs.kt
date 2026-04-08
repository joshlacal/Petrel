// Lexicon: 1, ID: com.atproto.sync.listBlobs
// List blob CIDs for an account, since some repo revision. Does not require auth; implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncListBlobsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.listBlobs"
}

@Serializable
    data class ComAtprotoSyncListBlobsParameters(
// The DID of the repo.        @SerialName("did")
        val did: DID,// Optional revision of the repo to list blobs since.        @SerialName("since")
        val since: String? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ComAtprotoSyncListBlobsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("cids")
        val cids: List<CID>    )

sealed class ComAtprotoSyncListBlobsError(val name: String, val description: String?) {
        object RepoNotFound: ComAtprotoSyncListBlobsError("RepoNotFound", "")
        object RepoTakendown: ComAtprotoSyncListBlobsError("RepoTakendown", "")
        object RepoSuspended: ComAtprotoSyncListBlobsError("RepoSuspended", "")
        object RepoDeactivated: ComAtprotoSyncListBlobsError("RepoDeactivated", "")
    }

/**
 * List blob CIDs for an account, since some repo revision. Does not require auth; implemented by PDS.
 *
 * Endpoint: com.atproto.sync.listBlobs
 */
suspend fun ATProtoClient.Com.Atproto.Sync.listBlobs(
parameters: ComAtprotoSyncListBlobsParameters): ATProtoResponse<ComAtprotoSyncListBlobsOutput> {
    val endpoint = "com.atproto.sync.listBlobs"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
