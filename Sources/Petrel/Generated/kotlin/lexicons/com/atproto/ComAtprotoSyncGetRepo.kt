// Lexicon: 1, ID: com.atproto.sync.getRepo
// Download a repository export as CAR file. Optionally only a 'diff' since a previous revision. Does not require auth; implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetRepoDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getRepo"
}

@Serializable
    data class ComAtprotoSyncGetRepoParameters(
// The DID of the repo.        @SerialName("did")
        val did: DID,// The revision ('rev') of the repo to create a diff from.        @SerialName("since")
        val since: String? = null    )

    @Serializable
    data class ComAtprotoSyncGetRepoOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class ComAtprotoSyncGetRepoError(val name: String, val description: String?) {
        object RepoNotFound: ComAtprotoSyncGetRepoError("RepoNotFound", "")
        object RepoTakendown: ComAtprotoSyncGetRepoError("RepoTakendown", "")
        object RepoSuspended: ComAtprotoSyncGetRepoError("RepoSuspended", "")
        object RepoDeactivated: ComAtprotoSyncGetRepoError("RepoDeactivated", "")
    }

/**
 * Download a repository export as CAR file. Optionally only a 'diff' since a previous revision. Does not require auth; implemented by PDS.
 *
 * Endpoint: com.atproto.sync.getRepo
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getRepo(
parameters: ComAtprotoSyncGetRepoParameters): ATProtoResponse<ComAtprotoSyncGetRepoOutput> {
    val endpoint = "com.atproto.sync.getRepo"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/vnd.ipld.car"),
        body = null
    )
}
