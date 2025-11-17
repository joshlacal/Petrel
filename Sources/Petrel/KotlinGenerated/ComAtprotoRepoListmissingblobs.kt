// Lexicon: 1, ID: com.atproto.repo.listMissingBlobs
// Returns a list of missing blobs for the requesting account. Intended to be used in the account migration flow.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoRepoListmissingblobs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.listMissingBlobs"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("blobs")
        val blobs: List<Recordblob>    )

        @Serializable
    data class Recordblob(
        @SerialName("cid")
        val cid: CID,        @SerialName("recordUri")
        val recordUri: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#recordblob"
        }
    }

}

/**
 * Returns a list of missing blobs for the requesting account. Intended to be used in the account migration flow.
 *
 * Endpoint: com.atproto.repo.listMissingBlobs
 */
suspend fun ATProtoClient.Com.Atproto.Repo.listmissingblobs(
parameters: ComAtprotoRepoListmissingblobs.Parameters): ATProtoResponse<ComAtprotoRepoListmissingblobs.Output> {
    val endpoint = "com.atproto.repo.listMissingBlobs"

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
