// Lexicon: 1, ID: com.atproto.sync.getRepoStatus
// Get the hosting status for a repository, on this server. Expected to be implemented by PDS and Relay.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetRepoStatusDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getRepoStatus"
}

@Serializable
    data class ComAtprotoSyncGetRepoStatusParameters(
// The DID of the repo.        @SerialName("did")
        val did: DID    )

    @Serializable
    data class ComAtprotoSyncGetRepoStatusOutput(
        @SerialName("did")
        val did: DID,        @SerialName("active")
        val active: Boolean,// If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted.        @SerialName("status")
        val status: String? = null,// Optional field, the current rev of the repo, if active=true        @SerialName("rev")
        val rev: String? = null    )

sealed class ComAtprotoSyncGetRepoStatusError(val name: String, val description: String?) {
        object RepoNotFound: ComAtprotoSyncGetRepoStatusError("RepoNotFound", "")
    }

/**
 * Get the hosting status for a repository, on this server. Expected to be implemented by PDS and Relay.
 *
 * Endpoint: com.atproto.sync.getRepoStatus
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getRepoStatus(
parameters: ComAtprotoSyncGetRepoStatusParameters): ATProtoResponse<ComAtprotoSyncGetRepoStatusOutput> {
    val endpoint = "com.atproto.sync.getRepoStatus"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
