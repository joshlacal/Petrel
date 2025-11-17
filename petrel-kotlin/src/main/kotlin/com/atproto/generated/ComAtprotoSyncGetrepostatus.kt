// Lexicon: 1, ID: com.atproto.sync.getRepoStatus
// Get the hosting status for a repository, on this server. Expected to be implemented by PDS and Relay.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncGetrepostatus {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getRepoStatus"

    @Serializable
    data class Parameters(
// The DID of the repo.        @SerialName("did")
        val did: DID    )

        @Serializable
    data class Output(
        @SerialName("did")
        val did: DID,        @SerialName("active")
        val active: Boolean,// If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted.        @SerialName("status")
        val status: String? = null,// Optional field, the current rev of the repo, if active=true        @SerialName("rev")
        val rev: String? = null    )

    sealed class Error(val name: String, val description: String?) {
        object Reponotfound: Error("RepoNotFound", "")
    }

}

/**
 * Get the hosting status for a repository, on this server. Expected to be implemented by PDS and Relay.
 *
 * Endpoint: com.atproto.sync.getRepoStatus
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getrepostatus(
parameters: ComAtprotoSyncGetrepostatus.Parameters): ATProtoResponse<ComAtprotoSyncGetrepostatus.Output> {
    val endpoint = "com.atproto.sync.getRepoStatus"

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
