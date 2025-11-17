// Lexicon: 1, ID: com.atproto.sync.getLatestCommit
// Get the current commit CID & revision of the specified repo. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncGetlatestcommit {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getLatestCommit"

    @Serializable
    data class Parameters(
// The DID of the repo.        @SerialName("did")
        val did: DID    )

        @Serializable
    data class Output(
        @SerialName("cid")
        val cid: CID,        @SerialName("rev")
        val rev: String    )

    sealed class Error(val name: String, val description: String?) {
        object Reponotfound: Error("RepoNotFound", "")
        object Repotakendown: Error("RepoTakendown", "")
        object Reposuspended: Error("RepoSuspended", "")
        object Repodeactivated: Error("RepoDeactivated", "")
    }

}

/**
 * Get the current commit CID & revision of the specified repo. Does not require auth.
 *
 * Endpoint: com.atproto.sync.getLatestCommit
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getlatestcommit(
parameters: ComAtprotoSyncGetlatestcommit.Parameters): ATProtoResponse<ComAtprotoSyncGetlatestcommit.Output> {
    val endpoint = "com.atproto.sync.getLatestCommit"

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
