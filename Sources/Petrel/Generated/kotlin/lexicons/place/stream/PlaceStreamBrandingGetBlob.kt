// Lexicon: 1, ID: place.stream.branding.getBlob
// Get a specific branding asset blob by key.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamBrandingGetBlobDefs {
    const val TYPE_IDENTIFIER = "place.stream.branding.getBlob"
}

@Serializable
    data class PlaceStreamBrandingGetBlobParameters(
// Branding asset key (mainLogo, favicon, siteTitle, etc.)        @SerialName("key")
        val key: String,// DID of the broadcaster. If not provided, uses the server's default broadcaster.        @SerialName("broadcaster")
        val broadcaster: DID? = null    )

    @Serializable
    data class PlaceStreamBrandingGetBlobOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class PlaceStreamBrandingGetBlobError(val name: String, val description: String?) {
        object BrandingNotFound: PlaceStreamBrandingGetBlobError("BrandingNotFound", "The requested branding asset does not exist")
    }

/**
 * Get a specific branding asset blob by key.
 *
 * Endpoint: place.stream.branding.getBlob
 */
suspend fun ATProtoClient.Place.Stream.Branding.getBlob(
parameters: PlaceStreamBrandingGetBlobParameters): ATProtoResponse<PlaceStreamBrandingGetBlobOutput> {
    val endpoint = "place.stream.branding.getBlob"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "*/*"),
        body = null
    )
}
