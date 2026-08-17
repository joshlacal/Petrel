// Lexicon: 1, ID: app.bsky.video.abortUpload
// Abort an upload only while it is created, releasing its quota reservation immediately. Terminal sessions are unchanged and return their terminal outcome. A finishing session returns UploadNotReady.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyVideoAbortUploadDefs {
    const val TYPE_IDENTIFIER = "app.bsky.video.abortUpload"
}

@Serializable
    data class AppBskyVideoAbortUploadInput(
        @SerialName("jobId")
        val jobId: String    )

    @Serializable
    data class AppBskyVideoAbortUploadOutput(
        @SerialName("state")
        val state: String,// Present only when state is completed.        @SerialName("completedJobId")
        val completedJobId: String? = null,// Present only when state is failed.        @SerialName("failureReason")
        val failureReason: String? = null    )

sealed class AppBskyVideoAbortUploadError(val name: String, val description: String?) {
        object UploadNotFound: AppBskyVideoAbortUploadError("UploadNotFound", "The job ID is unknown or aged out of retention; known terminal sessions return their outcome and are never reported as not found.")
        object UploadNotReady: AppBskyVideoAbortUploadError("UploadNotReady", "A finish is in progress; check getUploadStatus and retry.")
    }

/**
 * Abort an upload only while it is created, releasing its quota reservation immediately. Terminal sessions are unchanged and return their terminal outcome. A finishing session returns UploadNotReady.
 *
 * Endpoint: app.bsky.video.abortUpload
 */
suspend fun ATProtoClient.App.Bsky.Video.abortUpload(
input: AppBskyVideoAbortUploadInput): ATProtoResponse<AppBskyVideoAbortUploadOutput> {
    val endpoint = "app.bsky.video.abortUpload"

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
