// Lexicon: 1, ID: com.atproto.sync.getHead
// DEPRECATED - please use com.atproto.sync.getLatestCommit instead
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetHeadDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getHead"
}

@Serializable
    data class ComAtprotoSyncGetHeadParameters(
// The DID of the repo.        @SerialName("did")
        val did: DID    )

    @Serializable
    data class ComAtprotoSyncGetHeadOutput(
        @SerialName("root")
        val root: CID    )

sealed class ComAtprotoSyncGetHeadError(val name: String, val description: String?) {
        object HeadNotFound: ComAtprotoSyncGetHeadError("HeadNotFound", "")
    }

/**
 * DEPRECATED - please use com.atproto.sync.getLatestCommit instead
 *
 * Endpoint: com.atproto.sync.getHead
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getHead(
parameters: ComAtprotoSyncGetHeadParameters): ATProtoResponse<ComAtprotoSyncGetHeadOutput> {
    val endpoint = "com.atproto.sync.getHead"

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
