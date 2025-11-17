// Lexicon: 1, ID: app.bsky.labeler.getServices
// Get information about a list of labeler services.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface OutputViewsUnion {
    @Serializable
    @SerialName("AppBskyLabelerDefs.Labelerview")
    data class Labelerview(val value: AppBskyLabelerDefs.Labelerview) : OutputViewsUnion

    @Serializable
    @SerialName("AppBskyLabelerDefs.Labelerviewdetailed")
    data class Labelerviewdetailed(val value: AppBskyLabelerDefs.Labelerviewdetailed) : OutputViewsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : OutputViewsUnion
}

object AppBskyLabelerGetservices {
    const val TYPE_IDENTIFIER = "app.bsky.labeler.getServices"

    @Serializable
    data class Parameters(
        @SerialName("dids")
        val dids: List<DID>,        @SerialName("detailed")
        val detailed: Boolean? = null    )

        @Serializable
    data class Output(
        @SerialName("views")
        val views: List<OutputViewsUnion>    )

}

/**
 * Get information about a list of labeler services.
 *
 * Endpoint: app.bsky.labeler.getServices
 */
suspend fun ATProtoClient.App.Bsky.Labeler.getservices(
parameters: AppBskyLabelerGetservices.Parameters): ATProtoResponse<AppBskyLabelerGetservices.Output> {
    val endpoint = "app.bsky.labeler.getServices"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
