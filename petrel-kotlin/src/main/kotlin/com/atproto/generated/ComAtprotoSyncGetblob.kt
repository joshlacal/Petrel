// Lexicon: 1, ID: com.atproto.sync.getBlob
// Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncGetblob {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getBlob"

    @Serializable
    data class Parameters(
// The DID of the account.        @SerialName("did")
        val did: DID,// The CID of the blob to fetch        @SerialName("cid")
        val cid: CID    )

        @Serializable
    data class Output(
        @SerialName("data")
        val `data`: ByteArray    )

    sealed class Error(val name: String, val description: String?) {
        object Blobnotfound: Error("BlobNotFound", "")
        object Reponotfound: Error("RepoNotFound", "")
        object Repotakendown: Error("RepoTakendown", "")
        object Reposuspended: Error("RepoSuspended", "")
        object Repodeactivated: Error("RepoDeactivated", "")
    }

}

/**
 * Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.
 *
 * Endpoint: com.atproto.sync.getBlob
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getblob(
parameters: ComAtprotoSyncGetblob.Parameters): ATProtoResponse<ComAtprotoSyncGetblob.Output> {
    val endpoint = "com.atproto.sync.getBlob"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "*/*"),
        body = null
    )
}
