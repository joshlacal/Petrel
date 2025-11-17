// Lexicon: 1, ID: app.bsky.video.getJobStatus
// Get status details for a video processing job.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyVideoGetjobstatus {
    const val TYPE_IDENTIFIER = "app.bsky.video.getJobStatus"

    @Serializable
    data class Parameters(
        @SerialName("jobId")
        val jobId: String    )

        @Serializable
    data class Output(
        @SerialName("jobStatus")
        val jobStatus: AppBskyVideoDefs.Jobstatus    )

}

/**
 * Get status details for a video processing job.
 *
 * Endpoint: app.bsky.video.getJobStatus
 */
suspend fun ATProtoClient.App.Bsky.Video.getjobstatus(
parameters: AppBskyVideoGetjobstatus.Parameters): ATProtoResponse<AppBskyVideoGetjobstatus.Output> {
    val endpoint = "app.bsky.video.getJobStatus"

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
