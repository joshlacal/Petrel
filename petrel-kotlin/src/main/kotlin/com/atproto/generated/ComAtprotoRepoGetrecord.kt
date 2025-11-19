// Lexicon: 1, ID: com.atproto.repo.getRecord
// Get a single record from a repository. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoRepoGetrecord {
    const val TYPE_IDENTIFIER = "com.atproto.repo.getRecord"

    @Serializable
    data class Parameters(
// The handle or DID of the repo.        @SerialName("repo")
        val repo: ATIdentifier,// The NSID of the record collection.        @SerialName("collection")
        val collection: NSID,// The Record Key.        @SerialName("rkey")
        val rkey: String,// The CID of the version of the record. If not specified, then return the most recent version.        @SerialName("cid")
        val cid: CID? = null    )

        @Serializable
    data class Output(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID? = null,        @SerialName("value")
        val value: JsonElement    )

    sealed class Error(val name: String, val description: String?) {
        object Recordnotfound: Error("RecordNotFound", "")
    }

}

/**
 * Get a single record from a repository. Does not require auth.
 *
 * Endpoint: com.atproto.repo.getRecord
 */
suspend fun ATProtoClient.Com.Atproto.Repo.getrecord(
parameters: ComAtprotoRepoGetrecord.Parameters): ATProtoResponse<ComAtprotoRepoGetrecord.Output> {
    val endpoint = "com.atproto.repo.getRecord"

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
