// Lexicon: 1, ID: app.bsky.video.getUploadLimits
// Get video upload limits for the authenticated user.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyVideoGetUploadLimitsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.video.getUploadLimits"
}

    @Serializable
    data class AppBskyVideoGetUploadLimitsOutput(
        @SerialName("canUpload")
        val canUpload: Boolean,        @SerialName("remainingDailyVideos")
        val remainingDailyVideos: Int? = null,        @SerialName("remainingDailyBytes")
        val remainingDailyBytes: Int? = null,        @SerialName("message")
        val message: String? = null,        @SerialName("error")
        val error: String? = null    )

/**
 * Get video upload limits for the authenticated user.
 *
 * Endpoint: app.bsky.video.getUploadLimits
 */
suspend fun ATProtoClient.App.Bsky.Video.getUploadLimits(
): ATProtoResponse<AppBskyVideoGetUploadLimitsOutput> {
    val endpoint = "app.bsky.video.getUploadLimits"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
