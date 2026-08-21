// Lexicon: 1, ID: com.atproto.space.listRepos
// List the known repos that hold data in a space (the writer set), with each repo's current rev and commit hash. Served by the space host. This is the sync boundary, not an access-control list: it enumerates only writers, never readers. The set is what the authority claims from write notifications and is not itself authoritative; a repo's host is the source of truth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSpaceListReposDefs {
    const val TYPE_IDENTIFIER = "com.atproto.space.listRepos"
}

    @Serializable
    data class ComAtprotoSpaceListReposRepo(
/** The DID of a repo that holds data in the space. */        @SerialName("did")
        val did: DID,/** The repo's current revision (TID), as last reported to the authority. May lag the repo host, which is the source of truth. */        @SerialName("rev")
        val rev: String,/** The repo's current commit hash (sha256 of the LtHash state), as last reported to the authority. */        @SerialName("hash")
        val hash: Bytes    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSpaceListReposRepo"
        }
    }

@Serializable
    data class ComAtprotoSpaceListReposParameters(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef,// Maximum number of repos to return.        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ComAtprotoSpaceListReposOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("repos")
        val repos: List<ComAtprotoSpaceListReposRepo>    )

sealed class ComAtprotoSpaceListReposError(val name: String, val description: String?) {
        object SpaceNotFound: ComAtprotoSpaceListReposError("SpaceNotFound", "")
    }

/**
 * List the known repos that hold data in a space (the writer set), with each repo's current rev and commit hash. Served by the space host. This is the sync boundary, not an access-control list: it enumerates only writers, never readers. The set is what the authority claims from write notifications and is not itself authoritative; a repo's host is the source of truth.
 *
 * Endpoint: com.atproto.space.listRepos
 */
suspend fun ATProtoClient.Com.Atproto.Space.listRepos(
parameters: ComAtprotoSpaceListReposParameters): ATProtoResponse<ComAtprotoSpaceListReposOutput> {
    val endpoint = "com.atproto.space.listRepos"

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
