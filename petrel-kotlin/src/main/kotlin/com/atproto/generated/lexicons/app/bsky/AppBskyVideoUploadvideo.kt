// Lexicon: 1, ID: app.bsky.video.uploadVideo
// Upload a video to be processed then stored on the PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyVideoUploadVideoDefs {
    const val TYPE_IDENTIFIER = "app.bsky.video.uploadVideo"
}

@Serializable
    data class AppBskyVideoUploadVideoInput(
        @SerialName("data")
        val `data`: ByteArray    )

    @Serializable
    data class AppBskyVideoUploadVideoOutput(
        @SerialName("jobStatus")
        val jobStatus: AppBskyVideoDefsJobStatus    )

/**
 * Upload a video to be processed then stored on the PDS.
 *
 * Endpoint: app.bsky.video.uploadVideo
 */
suspend fun ATProtoClient.App.Bsky.Video.uploadVideo(
input: AppBskyVideoUploadVideoInput): ATProtoResponse<AppBskyVideoUploadVideoOutput> {
    val endpoint = "app.bsky.video.uploadVideo"

    // Binary data
    val body = input.data
    val contentType = "video/mp4"

    return client.networkService.performRequest(
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
