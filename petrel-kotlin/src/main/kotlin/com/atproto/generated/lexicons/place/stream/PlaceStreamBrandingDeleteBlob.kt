// Lexicon: 1, ID: place.stream.branding.deleteBlob
// Delete a branding asset blob. Requires admin authorization.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamBrandingDeleteBlobDefs {
    const val TYPE_IDENTIFIER = "place.stream.branding.deleteBlob"
}

@Serializable
    data class PlaceStreamBrandingDeleteBlobInput(
// Branding asset key (mainLogo, favicon, siteTitle, etc.)        @SerialName("key")
        val key: String,// DID of the broadcaster. If not provided, uses the server's default broadcaster.        @SerialName("broadcaster")
        val broadcaster: DID? = null    )

    @Serializable
    data class PlaceStreamBrandingDeleteBlobOutput(
        @SerialName("success")
        val success: Boolean    )

sealed class PlaceStreamBrandingDeleteBlobError(val name: String, val description: String?) {
        object Unauthorized: PlaceStreamBrandingDeleteBlobError("Unauthorized", "The authenticated DID is not authorized to modify branding")
        object BrandingNotFound: PlaceStreamBrandingDeleteBlobError("BrandingNotFound", "The requested branding asset does not exist")
    }

/**
 * Delete a branding asset blob. Requires admin authorization.
 *
 * Endpoint: place.stream.branding.deleteBlob
 */
suspend fun ATProtoClient.Place.Stream.Branding.deleteBlob(
input: PlaceStreamBrandingDeleteBlobInput): ATProtoResponse<PlaceStreamBrandingDeleteBlobOutput> {
    val endpoint = "place.stream.branding.deleteBlob"

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
            "Accept" to "application/json"
        ),
        body = body
    )
}
