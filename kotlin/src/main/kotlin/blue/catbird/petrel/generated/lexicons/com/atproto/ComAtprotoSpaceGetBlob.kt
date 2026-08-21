// Lexicon: 1, ID: com.atproto.space.getBlob
// Get a blob referenced from a record in a permissioned space. Returns the full blob as originally uploaded. Blobs are not uploaded through this namespace: a space record references a blob uploaded via com.atproto.repo.uploadBlob, so a client writing blob-bearing records into a space needs a blob permission alongside its space permission. Use listBlobs to enumerate a repo's blobs in a space. Callable with either OAuth (for the authenticated user's own data) or a space credential (for syncing services).
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSpaceGetBlobDefs {
    const val TYPE_IDENTIFIER = "com.atproto.space.getBlob"
}

@Serializable
    data class ComAtprotoSpaceGetBlobParameters(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef,// The DID of the account whose repo holds the blob.        @SerialName("repo")
        val repo: DID,// The CID of the blob to fetch.        @SerialName("cid")
        val cid: CID    )

    @Serializable
    data class ComAtprotoSpaceGetBlobOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class ComAtprotoSpaceGetBlobError(val name: String, val description: String?) {
        object BlobNotFound: ComAtprotoSpaceGetBlobError("BlobNotFound", "")
        object SpaceNotFound: ComAtprotoSpaceGetBlobError("SpaceNotFound", "")
        object RepoNotFound: ComAtprotoSpaceGetBlobError("RepoNotFound", "")
        object RepoTakendown: ComAtprotoSpaceGetBlobError("RepoTakendown", "")
        object RepoSuspended: ComAtprotoSpaceGetBlobError("RepoSuspended", "")
        object RepoDeactivated: ComAtprotoSpaceGetBlobError("RepoDeactivated", "")
    }

/**
 * Get a blob referenced from a record in a permissioned space. Returns the full blob as originally uploaded. Blobs are not uploaded through this namespace: a space record references a blob uploaded via com.atproto.repo.uploadBlob, so a client writing blob-bearing records into a space needs a blob permission alongside its space permission. Use listBlobs to enumerate a repo's blobs in a space. Callable with either OAuth (for the authenticated user's own data) or a space credential (for syncing services).
 *
 * Endpoint: com.atproto.space.getBlob
 */
suspend fun ATProtoClient.Com.Atproto.Space.getBlob(
parameters: ComAtprotoSpaceGetBlobParameters): ATProtoResponse<ComAtprotoSpaceGetBlobOutput> {
    val endpoint = "com.atproto.space.getBlob"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "*/*"),
        body = null
    )
}
