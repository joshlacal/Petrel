// Lexicon: 1, ID: blue.catbird.mlsChat.deleteBlob
// Delete an encrypted blob (owner only) Soft-delete an encrypted blob. Only the blob owner can delete it. The MLS message still contains the embed reference, but blob download will return 404 (same UX as expired blobs). Allows users to free quota space before the 90-day TTL.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatDeleteBlobDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.deleteBlob"
}

@Serializable
    data class BlueCatbirdMlsChatDeleteBlobInput(
// The blob identifier to delete        @SerialName("blobId")
        val blobId: String    )

sealed class BlueCatbirdMlsChatDeleteBlobError(val name: String, val description: String?) {
        object BlobNotFound: BlueCatbirdMlsChatDeleteBlobError("BlobNotFound", "Blob does not exist or is not owned by the authenticated user")
    }

/**
 * Delete an encrypted blob (owner only) Soft-delete an encrypted blob. Only the blob owner can delete it. The MLS message still contains the embed reference, but blob download will return 404 (same UX as expired blobs). Allows users to free quota space before the 90-day TTL.
 *
 * Endpoint: blue.catbird.mlsChat.deleteBlob
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.deleteBlob(
input: BlueCatbirdMlsChatDeleteBlobInput): ATProtoResponse<Unit> {
    val endpoint = "blue.catbird.mlsChat.deleteBlob"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
