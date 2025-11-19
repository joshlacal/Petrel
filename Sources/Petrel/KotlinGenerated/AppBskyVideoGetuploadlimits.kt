// Lexicon: 1, ID: app.bsky.video.getUploadLimits
// Get video upload limits for the authenticated user.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyVideoGetuploadlimits {
    const val TYPE_IDENTIFIER = "app.bsky.video.getUploadLimits"

        @Serializable
    data class Output(
        @SerialName("canUpload")
        val canUpload: Boolean,        @SerialName("remainingDailyVideos")
        val remainingDailyVideos: Int? = null,        @SerialName("remainingDailyBytes")
        val remainingDailyBytes: Int? = null,        @SerialName("message")
        val message: String? = null,        @SerialName("error")
        val error: String? = null    )

}

/**
 * Get video upload limits for the authenticated user.
 *
 * Endpoint: app.bsky.video.getUploadLimits
 */
suspend fun ATProtoClient.App.Bsky.Video.getuploadlimits(
): ATProtoResponse<AppBskyVideoGetuploadlimits.Output> {
    val endpoint = "app.bsky.video.getUploadLimits"

    val queryParams: Map<String, String>? = null

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
