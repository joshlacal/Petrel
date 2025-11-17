// Lexicon: 1, ID: com.atproto.sync.getRecord
// Get data blocks needed to prove the existence or non-existence of record in the current version of repo. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncGetrecord {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getRecord"

    @Serializable
    data class Parameters(
// The DID of the repo.        @SerialName("did")
        val did: DID,        @SerialName("collection")
        val collection: NSID,// Record Key        @SerialName("rkey")
        val rkey: String    )

        @Serializable
    data class Output(
        @SerialName("data")
        val `data`: ByteArray    )

    sealed class Error(val name: String, val description: String?) {
        object Recordnotfound: Error("RecordNotFound", "")
        object Reponotfound: Error("RepoNotFound", "")
        object Repotakendown: Error("RepoTakendown", "")
        object Reposuspended: Error("RepoSuspended", "")
        object Repodeactivated: Error("RepoDeactivated", "")
    }

}

/**
 * Get data blocks needed to prove the existence or non-existence of record in the current version of repo. Does not require auth.
 *
 * Endpoint: com.atproto.sync.getRecord
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getrecord(
parameters: ComAtprotoSyncGetrecord.Parameters): ATProtoResponse<ComAtprotoSyncGetrecord.Output> {
    val endpoint = "com.atproto.sync.getRecord"

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
