// Lexicon: 1, ID: blue.catbird.mlsChat.putGroupMetadataBlob
// Store an encrypted group metadata blob Upload an encrypted metadata blob. The blobLocator is client-generated (UUIDv4) and serves as the idempotency key. The server stores opaque bytes — it never sees plaintext metadata. Used for both metadata JSON blobs and encrypted avatar images. Clients should include convoId, resetGeneration, and metadataVersion when available so the server can scope metadata to the stable conversation across MLS group rotations.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatPutGroupMetadataBlobDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.putGroupMetadataBlob"
}

@Serializable
    data class BlueCatbirdMlsChatPutGroupMetadataBlobParameters(
// Client-generated UUIDv4 blob locator. Also the idempotency key.        @SerialName("blobLocator")
        val blobLocator: String,// Hex-encoded MLS group ID this metadata belongs to        @SerialName("groupId")
        val groupId: String,// Stable conversation identifier this metadata belongs to. When omitted, the server derives it from the current groupId for backward compatibility.        @SerialName("convoId")
        val convoId: String? = null,// Conversation reset generation for this encrypted blob. Defaults to the server's current generation for convoId/groupId.        @SerialName("resetGeneration")
        val resetGeneration: Int? = null,// Monotonic encrypted metadata version from the MLS MetadataReference.        @SerialName("metadataVersion")
        val metadataVersion: Int? = null,// Blob kind. Defaults to 'metadata'. Avatar blobs use 'avatar'.        @SerialName("kind")
        val kind: String? = null    )

@Serializable
    data class BlueCatbirdMlsChatPutGroupMetadataBlobInput(
        @SerialName("data")
        val `data`: ByteArray    )

    @Serializable
    data class BlueCatbirdMlsChatPutGroupMetadataBlobOutput(
// The blob locator (echoed from input parameter)        @SerialName("blobLocator")
        val blobLocator: String,// Stored blob size in bytes        @SerialName("size")
        val size: Int    )

sealed class BlueCatbirdMlsChatPutGroupMetadataBlobError(val name: String, val description: String?) {
        object BlobTooLarge: BlueCatbirdMlsChatPutGroupMetadataBlobError("BlobTooLarge", "Metadata blob exceeds maximum size (1MB)")
        object InvalidBlobLocator: BlueCatbirdMlsChatPutGroupMetadataBlobError("InvalidBlobLocator", "blobLocator is not a valid UUIDv4")
        object GroupNotFound: BlueCatbirdMlsChatPutGroupMetadataBlobError("GroupNotFound", "The specified group does not exist or caller is not a member")
    }

/**
 * Store an encrypted group metadata blob Upload an encrypted metadata blob. The blobLocator is client-generated (UUIDv4) and serves as the idempotency key. The server stores opaque bytes — it never sees plaintext metadata. Used for both metadata JSON blobs and encrypted avatar images. Clients should include convoId, resetGeneration, and metadataVersion when available so the server can scope metadata to the stable conversation across MLS group rotations.
 *
 * Endpoint: blue.catbird.mlsChat.putGroupMetadataBlob
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.putGroupMetadataBlob(
input: BlueCatbirdMlsChatPutGroupMetadataBlobInput,
    params: BlueCatbirdMlsChatPutGroupMetadataBlobParameters): ATProtoResponse<BlueCatbirdMlsChatPutGroupMetadataBlobOutput> {
    val endpoint = "blue.catbird.mlsChat.putGroupMetadataBlob"

    // Blob upload - input.data is ByteArray
    val body = input.data
    val contentType = "*/*"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = params.toQueryItems()

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
