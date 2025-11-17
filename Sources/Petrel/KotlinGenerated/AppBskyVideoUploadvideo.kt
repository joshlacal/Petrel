// Lexicon: 1, ID: app.bsky.video.uploadVideo
// Upload a video to be processed then stored on the PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyVideoUploadvideo {
    const val TYPE_IDENTIFIER = "app.bsky.video.uploadVideo"

    @Serializable
    data class Input(
        @SerialName("data")
        val `data`: ByteArray    )

        @Serializable
    data class Output(
        @SerialName("jobStatus")
        val jobStatus: AppBskyVideoDefs.Jobstatus    )

}

/**
 * Upload a video to be processed then stored on the PDS.
 *
 * Endpoint: app.bsky.video.uploadVideo
 */
suspend fun ATProtoClient.App.Bsky.Video.uploadvideo(
input: AppBskyVideoUploadvideo.Input): ATProtoResponse<AppBskyVideoUploadvideo.Output> {
    val endpoint = "app.bsky.video.uploadVideo"

    // Binary data
    val body = input.data
    val contentType = "video/mp4"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
