// Lexicon: 1, ID: com.atproto.space.getRecord
// Get a single record from a permissioned space. Callable with either OAuth (for the authenticated user's own data) or a space credential (for syncing services). Throws RepoNotFound when the account holds no repo in the space; this does not distinguish a member that has never written from a non-member.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSpaceGetRecordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.space.getRecord"
}

@Serializable
    data class ComAtprotoSpaceGetRecordParameters(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef,// The DID of the account whose repo to read from.        @SerialName("repo")
        val repo: DID,// The NSID of the record collection.        @SerialName("collection")
        val collection: NSID,// The Record Key.        @SerialName("rkey")
        val rkey: String    )

    @Serializable
    data class ComAtprotoSpaceGetRecordOutput(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("value")
        val value: JsonElement    )

sealed class ComAtprotoSpaceGetRecordError(val name: String, val description: String?) {
        object RecordNotFound: ComAtprotoSpaceGetRecordError("RecordNotFound", "")
        object SpaceNotFound: ComAtprotoSpaceGetRecordError("SpaceNotFound", "")
        object RepoNotFound: ComAtprotoSpaceGetRecordError("RepoNotFound", "")
        object RepoTakendown: ComAtprotoSpaceGetRecordError("RepoTakendown", "")
        object RepoSuspended: ComAtprotoSpaceGetRecordError("RepoSuspended", "")
        object RepoDeactivated: ComAtprotoSpaceGetRecordError("RepoDeactivated", "")
    }

/**
 * Get a single record from a permissioned space. Callable with either OAuth (for the authenticated user's own data) or a space credential (for syncing services). Throws RepoNotFound when the account holds no repo in the space; this does not distinguish a member that has never written from a non-member.
 *
 * Endpoint: com.atproto.space.getRecord
 */
suspend fun ATProtoClient.Com.Atproto.Space.getRecord(
parameters: ComAtprotoSpaceGetRecordParameters): ATProtoResponse<ComAtprotoSpaceGetRecordOutput> {
    val endpoint = "com.atproto.space.getRecord"

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
