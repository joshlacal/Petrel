// Lexicon: 1, ID: app.bsky.video.getJobStatus
// Get status details for a video processing job.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
