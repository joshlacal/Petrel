// Lexicon: 1, ID: com.atproto.space.createRecord
// Create a single new record in a permissioned space. Requires auth, implemented by PDS.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSpaceCreateRecordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.space.createRecord"
}

@Serializable
    data class ComAtprotoSpaceCreateRecordInput(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef,// The DID of the repo to write to (the authenticated member).        @SerialName("repo")
        val repo: DID,// The NSID of the record collection.        @SerialName("collection")
        val collection: NSID,// The Record Key.        @SerialName("rkey")
        val rkey: String? = null,// Can be set to 'false' to skip Lexicon schema validation of record data, 'true' to require it, or leave unset to validate only for known Lexicons.        @SerialName("validate")
        val validate: Boolean? = null,// The record itself. Must contain a $type field.        @SerialName("record")
        val record: JsonElement    )

    @Serializable
    data class ComAtprotoSpaceCreateRecordOutput(
// URI of the created record.        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("validationStatus")
        val validationStatus: String? = null    )

sealed class ComAtprotoSpaceCreateRecordError(val name: String, val description: String?) {
        object SpaceNotFound: ComAtprotoSpaceCreateRecordError("SpaceNotFound", "")
        object RecordAlreadyExists: ComAtprotoSpaceCreateRecordError("RecordAlreadyExists", "A record already exists at this collection and rkey. Retry with a different rkey, or use putRecord.")
    }

/**
 * Create a single new record in a permissioned space. Requires auth, implemented by PDS.
 *
 * Endpoint: com.atproto.space.createRecord
 */
suspend fun ATProtoClient.Com.Atproto.Space.createRecord(
input: ComAtprotoSpaceCreateRecordInput): ATProtoResponse<ComAtprotoSpaceCreateRecordOutput> {
    val endpoint = "com.atproto.space.createRecord"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
