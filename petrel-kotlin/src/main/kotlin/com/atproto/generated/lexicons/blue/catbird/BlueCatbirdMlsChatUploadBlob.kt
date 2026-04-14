// Lexicon: 1, ID: blue.catbird.mlsChat.uploadBlob
// Upload an encrypted blob for image DM attachments Upload an encrypted blob to the blob store. The server assigns a blobId (UUIDv4) on success. Content-Type must be application/octet-stream. The blob bytes are opaque encrypted data — the server never sees plaintext. The uploader must be an active member of the target conversation.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatUploadBlobDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.uploadBlob"
}

@Serializable
    data class BlueCatbirdMlsChatUploadBlobParameters(
// The conversation ID this blob belongs to. Used for authorization — only conversation members can download the blob.        @SerialName("convoId")
        val convoId: String    )

@Serializable
    data class BlueCatbirdMlsChatUploadBlobInput(
        @SerialName("data")
        val `data`: ByteArray    )

    @Serializable
    data class BlueCatbirdMlsChatUploadBlobOutput(
// Server-assigned UUIDv4 blob identifier        @SerialName("blobId")
        val blobId: String,// Stored blob size in bytes        @SerialName("size")
        val size: Int    )

sealed class BlueCatbirdMlsChatUploadBlobError(val name: String, val description: String?) {
        object QuotaExceeded: BlueCatbirdMlsChatUploadBlobError("QuotaExceeded", "User's blob storage quota has been exceeded (500MB per user)")
        object BlobTooLarge: BlueCatbirdMlsChatUploadBlobError("BlobTooLarge", "Blob exceeds maximum size (10MB)")
        object NotAMember: BlueCatbirdMlsChatUploadBlobError("NotAMember", "Uploader is not an active member of the target conversation")
    }

/**
 * Upload an encrypted blob for image DM attachments Upload an encrypted blob to the blob store. The server assigns a blobId (UUIDv4) on success. Content-Type must be application/octet-stream. The blob bytes are opaque encrypted data — the server never sees plaintext. The uploader must be an active member of the target conversation.
 *
 * Endpoint: blue.catbird.mlsChat.uploadBlob
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.uploadBlob(
input: BlueCatbirdMlsChatUploadBlobInput,
    params: BlueCatbirdMlsChatUploadBlobParameters): ATProtoResponse<BlueCatbirdMlsChatUploadBlobOutput> {
    val endpoint = "blue.catbird.mlsChat.uploadBlob"

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
