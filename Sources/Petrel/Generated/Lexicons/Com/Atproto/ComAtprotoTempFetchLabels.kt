// Lexicon: 1, ID: com.atproto.temp.fetchLabels
// DEPRECATED: use queryLabels or subscribeLabels instead -- Fetch all labels from a labeler created after a certain date.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoTempFetchLabelsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.temp.fetchLabels"
}

@Serializable
    data class ComAtprotoTempFetchLabelsParameters(
        @SerialName("since")
        val since: Int? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class ComAtprotoTempFetchLabelsOutput(
        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>    )

/**
 * DEPRECATED: use queryLabels or subscribeLabels instead -- Fetch all labels from a labeler created after a certain date.
 *
 * Endpoint: com.atproto.temp.fetchLabels
 */
suspend fun ATProtoClient.Com.Atproto.Temp.fetchLabels(
parameters: ComAtprotoTempFetchLabelsParameters): ATProtoResponse<ComAtprotoTempFetchLabelsOutput> {
    val endpoint = "com.atproto.temp.fetchLabels"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
