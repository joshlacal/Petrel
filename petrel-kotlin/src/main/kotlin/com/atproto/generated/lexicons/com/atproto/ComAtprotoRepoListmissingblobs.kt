// Lexicon: 1, ID: com.atproto.repo.listMissingBlobs
// Returns a list of missing blobs for the requesting account. Intended to be used in the account migration flow.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoRepoListMissingBlobsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.listMissingBlobs"
}

    @Serializable
    data class ComAtprotoRepoListMissingBlobsRecordBlob(
        @SerialName("cid")
        val cid: CID,        @SerialName("recordUri")
        val recordUri: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoRepoListMissingBlobsRecordBlob"
        }
    }

@Serializable
    data class ComAtprotoRepoListMissingBlobsParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ComAtprotoRepoListMissingBlobsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("blobs")
        val blobs: List<ComAtprotoRepoListMissingBlobsRecordBlob>    )

/**
 * Returns a list of missing blobs for the requesting account. Intended to be used in the account migration flow.
 *
 * Endpoint: com.atproto.repo.listMissingBlobs
 */
suspend fun ATProtoClient.Com.Atproto.Repo.listMissingBlobs(
parameters: ComAtprotoRepoListMissingBlobsParameters): ATProtoResponse<ComAtprotoRepoListMissingBlobsOutput> {
    val endpoint = "com.atproto.repo.listMissingBlobs"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
