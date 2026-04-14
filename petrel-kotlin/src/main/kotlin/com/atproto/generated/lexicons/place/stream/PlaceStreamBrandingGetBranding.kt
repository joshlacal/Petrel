// Lexicon: 1, ID: place.stream.branding.getBranding
// Get all branding configuration for the broadcaster.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamBrandingGetBrandingDefs {
    const val TYPE_IDENTIFIER = "place.stream.branding.getBranding"
}

    @Serializable
    data class PlaceStreamBrandingGetBrandingBrandingAsset(
/** Asset key identifier */        @SerialName("key")
        val key: String,/** MIME type of the asset */        @SerialName("mimeType")
        val mimeType: String,/** URL to fetch the asset blob (for images) */        @SerialName("url")
        val url: String? = null,/** Inline data for text assets */        @SerialName("data")
        val `data`: String? = null,/** Image width in pixels (optional, for images only) */        @SerialName("width")
        val width: Int? = null,/** Image height in pixels (optional, for images only) */        @SerialName("height")
        val height: Int? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamBrandingGetBrandingBrandingAsset"
        }
    }

@Serializable
    data class PlaceStreamBrandingGetBrandingParameters(
// DID of the broadcaster. If not provided, uses the server's default broadcaster.        @SerialName("broadcaster")
        val broadcaster: DID? = null    )

    @Serializable
    data class PlaceStreamBrandingGetBrandingOutput(
// List of available branding assets        @SerialName("assets")
        val assets: List<PlaceStreamBrandingGetBrandingBrandingAsset>    )

/**
 * Get all branding configuration for the broadcaster.
 *
 * Endpoint: place.stream.branding.getBranding
 */
suspend fun ATProtoClient.Place.Stream.Branding.getBranding(
parameters: PlaceStreamBrandingGetBrandingParameters): ATProtoResponse<PlaceStreamBrandingGetBrandingOutput> {
    val endpoint = "place.stream.branding.getBranding"

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
