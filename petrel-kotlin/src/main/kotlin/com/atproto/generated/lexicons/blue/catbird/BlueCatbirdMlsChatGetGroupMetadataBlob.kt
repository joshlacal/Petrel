// Lexicon: 1, ID: blue.catbird.mlsChat.getGroupMetadataBlob
// Fetch an encrypted group metadata blob by locator Download an encrypted metadata blob. Returns raw encrypted bytes. The blob is opaque — decryption requires the MLS epoch key derived by group members.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetGroupMetadataBlobDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getGroupMetadataBlob"
}

@Serializable
    data class BlueCatbirdMlsChatGetGroupMetadataBlobParameters(
// Optional blob locator. When omitted or empty, returns the latest blob for the group.        @SerialName("blobLocator")
        val blobLocator: String? = null,// Hex-encoded MLS group ID (for server-side membership check)        @SerialName("groupId")
        val groupId: String    )

    @Serializable
    data class BlueCatbirdMlsChatGetGroupMetadataBlobOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class BlueCatbirdMlsChatGetGroupMetadataBlobError(val name: String, val description: String?) {
        object BlobNotFound: BlueCatbirdMlsChatGetGroupMetadataBlobError("BlobNotFound", "Metadata blob does not exist or has been garbage collected")
    }

/**
 * Fetch an encrypted group metadata blob by locator Download an encrypted metadata blob. Returns raw encrypted bytes. The blob is opaque — decryption requires the MLS epoch key derived by group members.
 *
 * Endpoint: blue.catbird.mlsChat.getGroupMetadataBlob
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getGroupMetadataBlob(
parameters: BlueCatbirdMlsChatGetGroupMetadataBlobParameters): ATProtoResponse<BlueCatbirdMlsChatGetGroupMetadataBlobOutput> {
    val endpoint = "blue.catbird.mlsChat.getGroupMetadataBlob"

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
