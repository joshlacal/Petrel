// Lexicon: 1, ID: com.atproto.label.queryLabels
// Find labels relevant to the provided AT-URI patterns. Public endpoint for moderation services, though may return different or additional results with auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoLabelQuerylabels {
    const val TYPE_IDENTIFIER = "com.atproto.label.queryLabels"

    @Serializable
    data class Parameters(
// List of AT URI patterns to match (boolean 'OR'). Each may be a prefix (ending with '*'; will match inclusive of the string leading to '*'), or a full URI.        @SerialName("uriPatterns")
        val uriPatterns: List<String>,// Optional list of label sources (DIDs) to filter on.        @SerialName("sources")
        val sources: List<DID>? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>    )

}

/**
 * Find labels relevant to the provided AT-URI patterns. Public endpoint for moderation services, though may return different or additional results with auth.
 *
 * Endpoint: com.atproto.label.queryLabels
 */
suspend fun ATProtoClient.Com.Atproto.Label.querylabels(
parameters: ComAtprotoLabelQuerylabels.Parameters): ATProtoResponse<ComAtprotoLabelQuerylabels.Output> {
    val endpoint = "com.atproto.label.queryLabels"

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
