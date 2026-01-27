// Lexicon: 1, ID: com.atproto.label.queryLabels
// Find labels relevant to the provided AT-URI patterns. Public endpoint for moderation services, though may return different or additional results with auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoLabelQueryLabelsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.label.queryLabels"
}

@Serializable
    data class ComAtprotoLabelQueryLabelsParameters(
// List of AT URI patterns to match (boolean 'OR'). Each may be a prefix (ending with '*'; will match inclusive of the string leading to '*'), or a full URI.        @SerialName("uriPatterns")
        val uriPatterns: List<String>,// Optional list of label sources (DIDs) to filter on.        @SerialName("sources")
        val sources: List<DID>? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ComAtprotoLabelQueryLabelsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>    )

/**
 * Find labels relevant to the provided AT-URI patterns. Public endpoint for moderation services, though may return different or additional results with auth.
 *
 * Endpoint: com.atproto.label.queryLabels
 */
suspend fun ATProtoClient.Com.Atproto.Label.queryLabels(
parameters: ComAtprotoLabelQueryLabelsParameters): ATProtoResponse<ComAtprotoLabelQueryLabelsOutput> {
    val endpoint = "com.atproto.label.queryLabels"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
