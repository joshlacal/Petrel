// Lexicon: 1, ID: app.bsky.labeler.getServices
// Get information about a list of labeler services.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyLabelerGetServicesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.labeler.getServices"
}

@Serializable
sealed interface AppBskyLabelerGetServicesOutputViewsUnion {
    @Serializable
    @SerialName("app.bsky.labeler.getServices#AppBskyLabelerDefsLabelerView")
    data class AppBskyLabelerDefsLabelerView(val value: AppBskyLabelerDefsLabelerView) : AppBskyLabelerGetServicesOutputViewsUnion

    @Serializable
    @SerialName("app.bsky.labeler.getServices#AppBskyLabelerDefsLabelerViewDetailed")
    data class AppBskyLabelerDefsLabelerViewDetailed(val value: AppBskyLabelerDefsLabelerViewDetailed) : AppBskyLabelerGetServicesOutputViewsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyLabelerGetServicesOutputViewsUnion
}

@Serializable
    data class AppBskyLabelerGetServicesParameters(
        @SerialName("dids")
        val dids: List<DID>,        @SerialName("detailed")
        val detailed: Boolean? = null    )

    @Serializable
    data class AppBskyLabelerGetServicesOutput(
        @SerialName("views")
        val views: List<AppBskyLabelerGetServicesOutputViewsUnion>    )

/**
 * Get information about a list of labeler services.
 *
 * Endpoint: app.bsky.labeler.getServices
 */
suspend fun ATProtoClient.App.Bsky.Labeler.getServices(
parameters: AppBskyLabelerGetServicesParameters): ATProtoResponse<AppBskyLabelerGetServicesOutput> {
    val endpoint = "app.bsky.labeler.getServices"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
