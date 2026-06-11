// Lexicon: 1, ID: com.atproto.sync.getBlocks
// Get data blocks from a given repo, by CID. For example, intermediate MST nodes, or records. Does not require auth; implemented by PDS.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetBlocksDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getBlocks"
}

@Serializable
    data class ComAtprotoSyncGetBlocksParameters(
// The DID of the repo.        @SerialName("did")
        val did: DID,        @SerialName("cids")
        val cids: List<CID>    )

    @Serializable
    data class ComAtprotoSyncGetBlocksOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class ComAtprotoSyncGetBlocksError(val name: String, val description: String?) {
        object BlockNotFound: ComAtprotoSyncGetBlocksError("BlockNotFound", "")
        object RepoNotFound: ComAtprotoSyncGetBlocksError("RepoNotFound", "")
        object RepoTakendown: ComAtprotoSyncGetBlocksError("RepoTakendown", "")
        object RepoSuspended: ComAtprotoSyncGetBlocksError("RepoSuspended", "")
        object RepoDeactivated: ComAtprotoSyncGetBlocksError("RepoDeactivated", "")
    }

/**
 * Get data blocks from a given repo, by CID. For example, intermediate MST nodes, or records. Does not require auth; implemented by PDS.
 *
 * Endpoint: com.atproto.sync.getBlocks
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getBlocks(
parameters: ComAtprotoSyncGetBlocksParameters): ATProtoResponse<ComAtprotoSyncGetBlocksOutput> {
    val endpoint = "com.atproto.sync.getBlocks"

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
