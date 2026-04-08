// Lexicon: 1, ID: place.stream.branding.updateBlob
// Update or create a branding asset blob. Requires admin authorization.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamBrandingUpdateBlobDefs {
    const val TYPE_IDENTIFIER = "place.stream.branding.updateBlob"
}

@Serializable
    data class PlaceStreamBrandingUpdateBlobInput(
// Branding asset key (mainLogo, favicon, siteTitle, etc.)        @SerialName("key")
        val key: String,// DID of the broadcaster. If not provided, uses the server's default broadcaster.        @SerialName("broadcaster")
        val broadcaster: DID? = null,// Base64-encoded blob data        @SerialName("data")
        val `data`: String,// MIME type of the blob (e.g., image/png, text/plain)        @SerialName("mimeType")
        val mimeType: String,// Image width in pixels (optional, for images only)        @SerialName("width")
        val width: Int? = null,// Image height in pixels (optional, for images only)        @SerialName("height")
        val height: Int? = null    )

    @Serializable
    data class PlaceStreamBrandingUpdateBlobOutput(
        @SerialName("success")
        val success: Boolean    )

sealed class PlaceStreamBrandingUpdateBlobError(val name: String, val description: String?) {
        object Unauthorized: PlaceStreamBrandingUpdateBlobError("Unauthorized", "The authenticated DID is not authorized to modify branding")
        object BlobTooLarge: PlaceStreamBrandingUpdateBlobError("BlobTooLarge", "The blob exceeds the maximum size limit")
    }

/**
 * Update or create a branding asset blob. Requires admin authorization.
 *
 * Endpoint: place.stream.branding.updateBlob
 */
suspend fun ATProtoClient.Place.Stream.Branding.updateBlob(
input: PlaceStreamBrandingUpdateBlobInput): ATProtoResponse<PlaceStreamBrandingUpdateBlobOutput> {
    val endpoint = "place.stream.branding.updateBlob"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
