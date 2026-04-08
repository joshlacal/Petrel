// Lexicon: 1, ID: app.bsky.video.getJobStatus
// Get status details for a video processing job.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyVideoGetJobStatusDefs {
    const val TYPE_IDENTIFIER = "app.bsky.video.getJobStatus"
}

@Serializable
    data class AppBskyVideoGetJobStatusParameters(
        @SerialName("jobId")
        val jobId: String    )

    @Serializable
    data class AppBskyVideoGetJobStatusOutput(
        @SerialName("jobStatus")
        val jobStatus: AppBskyVideoDefsJobStatus    )

/**
 * Get status details for a video processing job.
 *
 * Endpoint: app.bsky.video.getJobStatus
 */
suspend fun ATProtoClient.App.Bsky.Video.getJobStatus(
parameters: AppBskyVideoGetJobStatusParameters): ATProtoResponse<AppBskyVideoGetJobStatusOutput> {
    val endpoint = "app.bsky.video.getJobStatus"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
