// Lexicon: 1, ID: com.atproto.sync.getBlob
// Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetBlobDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getBlob"
}

@Serializable
    data class ComAtprotoSyncGetBlobParameters(
// The DID of the account.        @SerialName("did")
        val did: DID,// The CID of the blob to fetch        @SerialName("cid")
        val cid: CID    )

    @Serializable
    data class ComAtprotoSyncGetBlobOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class ComAtprotoSyncGetBlobError(val name: String, val description: String?) {
        object BlobNotFound: ComAtprotoSyncGetBlobError("BlobNotFound", "")
        object RepoNotFound: ComAtprotoSyncGetBlobError("RepoNotFound", "")
        object RepoTakendown: ComAtprotoSyncGetBlobError("RepoTakendown", "")
        object RepoSuspended: ComAtprotoSyncGetBlobError("RepoSuspended", "")
        object RepoDeactivated: ComAtprotoSyncGetBlobError("RepoDeactivated", "")
    }

/**
 * Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.
 *
 * Endpoint: com.atproto.sync.getBlob
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getBlob(
parameters: ComAtprotoSyncGetBlobParameters): ATProtoResponse<ComAtprotoSyncGetBlobOutput> {
    val endpoint = "com.atproto.sync.getBlob"

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
