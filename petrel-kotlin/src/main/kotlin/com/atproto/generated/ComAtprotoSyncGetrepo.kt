// Lexicon: 1, ID: com.atproto.sync.getRepo
// Download a repository export as CAR file. Optionally only a 'diff' since a previous revision. Does not require auth; implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncGetrepo {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getRepo"

    @Serializable
    data class Parameters(
// The DID of the repo.        @SerialName("did")
        val did: DID,// The revision ('rev') of the repo to create a diff from.        @SerialName("since")
        val since: String? = null    )

        @Serializable
    data class Output(
        @SerialName("data")
        val `data`: ByteArray    )

    sealed class Error(val name: String, val description: String?) {
        object Reponotfound: Error("RepoNotFound", "")
        object Repotakendown: Error("RepoTakendown", "")
        object Reposuspended: Error("RepoSuspended", "")
        object Repodeactivated: Error("RepoDeactivated", "")
    }

}

/**
 * Download a repository export as CAR file. Optionally only a 'diff' since a previous revision. Does not require auth; implemented by PDS.
 *
 * Endpoint: com.atproto.sync.getRepo
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getrepo(
parameters: ComAtprotoSyncGetrepo.Parameters): ATProtoResponse<ComAtprotoSyncGetrepo.Output> {
    val endpoint = "com.atproto.sync.getRepo"

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
