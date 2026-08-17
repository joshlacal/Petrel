// Lexicon: 1, ID: app.bsky.video.startUpload
// Start a multipart video upload. The declared size is exact, while optional media properties are advisory and used only for early failure; the authoritative probe runs asynchronously after upload.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyVideoStartUploadDefs {
    const val TYPE_IDENTIFIER = "app.bsky.video.startUpload"
}

@Serializable
    data class AppBskyVideoStartUploadInput(
// Exact byte size of the complete upload-ready video file before it is split into parts.        @SerialName("sizeBytes")
        val sizeBytes: Int,// Declared MIME type of the video.        @SerialName("mimeType")
        val mimeType: String,// Optional client-provided file name.        @SerialName("name")
        val name: String? = null,// Advisory, non-authoritative duration used only for early failure; the authoritative probe runs asynchronously after upload.        @SerialName("durationMs")
        val durationMs: Int? = null,// Advisory, non-authoritative width used only for early failure; the authoritative probe runs asynchronously after upload.        @SerialName("width")
        val width: Int? = null,// Advisory, non-authoritative height used only for early failure; the authoritative probe runs asynchronously after upload.        @SerialName("height")
        val height: Int? = null    )

    @Serializable
    data class AppBskyVideoStartUploadOutput(
        @SerialName("jobId")
        val jobId: String,        @SerialName("partSizeBytes")
        val partSizeBytes: Int,        @SerialName("partCount")
        val partCount: Int,        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate    )

sealed class AppBskyVideoStartUploadError(val name: String, val description: String?) {
        object UnsupportedContentType: AppBskyVideoStartUploadError("UnsupportedContentType", "The declared MIME type is not supported.")
        object VideoTooLarge: AppBskyVideoStartUploadError("VideoTooLarge", "The exact file size exceeds the per-file cap or remaining daily byte allowance.")
        object VideoTooLong: AppBskyVideoStartUploadError("VideoTooLong", "The advisory declared duration exceeds the limit.")
        object BadAspectRatio: AppBskyVideoStartUploadError("BadAspectRatio", "The advisory declared dimensions have an unsupported aspect ratio.")
        object DailyLimitExceeded: AppBskyVideoStartUploadError("DailyLimitExceeded", "The daily video or byte allowance, including active reservations, is exhausted.")
        object TooManyOpenUploads: AppBskyVideoStartUploadError("TooManyOpenUploads", "The account has reached its open multipart upload limit.")
        object UploadForbidden: AppBskyVideoStartUploadError("UploadForbidden", "The account is not permitted to upload video.")
        object ServiceOverloaded: AppBskyVideoStartUploadError("ServiceOverloaded", "The service is draining, at capacity, or temporarily unable to create the multipart upload.")
    }

/**
 * Start a multipart video upload. The declared size is exact, while optional media properties are advisory and used only for early failure; the authoritative probe runs asynchronously after upload.
 *
 * Endpoint: app.bsky.video.startUpload
 */
suspend fun ATProtoClient.App.Bsky.Video.startUpload(
input: AppBskyVideoStartUploadInput): ATProtoResponse<AppBskyVideoStartUploadOutput> {
    val endpoint = "app.bsky.video.startUpload"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
