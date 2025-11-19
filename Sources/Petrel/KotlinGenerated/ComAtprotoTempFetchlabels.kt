// Lexicon: 1, ID: com.atproto.temp.fetchLabels
// DEPRECATED: use queryLabels or subscribeLabels instead -- Fetch all labels from a labeler created after a certain date.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoTempFetchlabels {
    const val TYPE_IDENTIFIER = "com.atproto.temp.fetchLabels"

    @Serializable
    data class Parameters(
        @SerialName("since")
        val since: Int? = null,        @SerialName("limit")
        val limit: Int? = null    )

        @Serializable
    data class Output(
        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>    )

}

/**
 * DEPRECATED: use queryLabels or subscribeLabels instead -- Fetch all labels from a labeler created after a certain date.
 *
 * Endpoint: com.atproto.temp.fetchLabels
 */
suspend fun ATProtoClient.Com.Atproto.Temp.fetchlabels(
parameters: ComAtprotoTempFetchlabels.Parameters): ATProtoResponse<ComAtprotoTempFetchlabels.Output> {
    val endpoint = "com.atproto.temp.fetchLabels"

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
