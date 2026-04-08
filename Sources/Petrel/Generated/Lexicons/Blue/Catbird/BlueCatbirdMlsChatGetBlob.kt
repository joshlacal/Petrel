// Lexicon: 1, ID: blue.catbird.mlsChat.getBlob
// Download an encrypted blob by ID Fetch an encrypted blob from the blob store. Returns raw encrypted bytes (application/octet-stream). Only active members of the blob's conversation can download it.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetBlobDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getBlob"
}

@Serializable
    data class BlueCatbirdMlsChatGetBlobParameters(
// The blob identifier to download        @SerialName("blobId")
        val blobId: String    )

    @Serializable
    data class BlueCatbirdMlsChatGetBlobOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class BlueCatbirdMlsChatGetBlobError(val name: String, val description: String?) {
        object BlobNotFound: BlueCatbirdMlsChatGetBlobError("BlobNotFound", "Blob does not exist or has expired/been deleted")
        object NotAMember: BlueCatbirdMlsChatGetBlobError("NotAMember", "Requester is not an active member of the blob's conversation")
    }

/**
 * Download an encrypted blob by ID Fetch an encrypted blob from the blob store. Returns raw encrypted bytes (application/octet-stream). Only active members of the blob's conversation can download it.
 *
 * Endpoint: blue.catbird.mlsChat.getBlob
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getBlob(
parameters: BlueCatbirdMlsChatGetBlobParameters): ATProtoResponse<BlueCatbirdMlsChatGetBlobOutput> {
    val endpoint = "blue.catbird.mlsChat.getBlob"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "*/*"),
        body = null
    )
}
