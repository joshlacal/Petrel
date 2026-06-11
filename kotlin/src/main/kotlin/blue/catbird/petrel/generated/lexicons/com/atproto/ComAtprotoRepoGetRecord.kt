// Lexicon: 1, ID: com.atproto.repo.getRecord
// Get a single record from a repository. Does not require auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoRepoGetRecordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.getRecord"
}

@Serializable
    data class ComAtprotoRepoGetRecordParameters(
// The handle or DID of the repo.        @SerialName("repo")
        val repo: ATIdentifier,// The NSID of the record collection.        @SerialName("collection")
        val collection: NSID,// The Record Key.        @SerialName("rkey")
        val rkey: String,// The CID of the version of the record. If not specified, then return the most recent version.        @SerialName("cid")
        val cid: CID? = null    )

    @Serializable
    data class ComAtprotoRepoGetRecordOutput(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID? = null,        @SerialName("value")
        val value: JsonElement    )

sealed class ComAtprotoRepoGetRecordError(val name: String, val description: String?) {
        object RecordNotFound: ComAtprotoRepoGetRecordError("RecordNotFound", "")
    }

/**
 * Get a single record from a repository. Does not require auth.
 *
 * Endpoint: com.atproto.repo.getRecord
 */
suspend fun ATProtoClient.Com.Atproto.Repo.getRecord(
parameters: ComAtprotoRepoGetRecordParameters): ATProtoResponse<ComAtprotoRepoGetRecordOutput> {
    val endpoint = "com.atproto.repo.getRecord"

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
