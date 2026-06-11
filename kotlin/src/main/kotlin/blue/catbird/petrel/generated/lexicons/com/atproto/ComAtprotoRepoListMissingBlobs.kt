// Lexicon: 1, ID: com.atproto.repo.listMissingBlobs
// Returns a list of missing blobs for the requesting account. Intended to be used in the account migration flow.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoRepoListMissingBlobsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.listMissingBlobs"
}

    @Serializable
    data class ComAtprotoRepoListMissingBlobsRecordBlob(
        @SerialName("cid")
        val cid: CID,        @SerialName("recordUri")
        val recordUri: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoRepoListMissingBlobsRecordBlob"
        }
    }

@Serializable
    data class ComAtprotoRepoListMissingBlobsParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ComAtprotoRepoListMissingBlobsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("blobs")
        val blobs: List<ComAtprotoRepoListMissingBlobsRecordBlob>    )

/**
 * Returns a list of missing blobs for the requesting account. Intended to be used in the account migration flow.
 *
 * Endpoint: com.atproto.repo.listMissingBlobs
 */
suspend fun ATProtoClient.Com.Atproto.Repo.listMissingBlobs(
parameters: ComAtprotoRepoListMissingBlobsParameters): ATProtoResponse<ComAtprotoRepoListMissingBlobsOutput> {
    val endpoint = "com.atproto.repo.listMissingBlobs"

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
