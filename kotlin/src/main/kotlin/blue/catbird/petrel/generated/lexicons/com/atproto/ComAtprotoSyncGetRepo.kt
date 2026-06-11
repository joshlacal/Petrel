// Lexicon: 1, ID: com.atproto.sync.getRepo
// Download a repository export as CAR file. Optionally only a 'diff' since a previous revision. Does not require auth; implemented by PDS.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/vnd.ipld.car"),
        body = null
    )
}
