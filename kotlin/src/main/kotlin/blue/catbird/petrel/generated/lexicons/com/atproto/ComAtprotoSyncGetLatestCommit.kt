// Lexicon: 1, ID: com.atproto.sync.getLatestCommit
// Get the current commit CID & revision of the specified repo. Does not require auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetLatestCommitDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getLatestCommit"
}

@Serializable
    data class ComAtprotoSyncGetLatestCommitParameters(
// The DID of the repo.        @SerialName("did")
        val did: DID    )

    @Serializable
    data class ComAtprotoSyncGetLatestCommitOutput(
        @SerialName("cid")
        val cid: CID,        @SerialName("rev")
        val rev: String    )

sealed class ComAtprotoSyncGetLatestCommitError(val name: String, val description: String?) {
        object RepoNotFound: ComAtprotoSyncGetLatestCommitError("RepoNotFound", "")
        object RepoTakendown: ComAtprotoSyncGetLatestCommitError("RepoTakendown", "")
        object RepoSuspended: ComAtprotoSyncGetLatestCommitError("RepoSuspended", "")
        object RepoDeactivated: ComAtprotoSyncGetLatestCommitError("RepoDeactivated", "")
    }

/**
 * Get the current commit CID & revision of the specified repo. Does not require auth.
 *
 * Endpoint: com.atproto.sync.getLatestCommit
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getLatestCommit(
parameters: ComAtprotoSyncGetLatestCommitParameters): ATProtoResponse<ComAtprotoSyncGetLatestCommitOutput> {
    val endpoint = "com.atproto.sync.getLatestCommit"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
