// Lexicon: 1, ID: app.bsky.notification.listNotifications
// Enumerate notifications for the requesting account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyNotificationListnotifications {
    const val TYPE_IDENTIFIER = "app.bsky.notification.listNotifications"

    @Serializable
    data class Parameters(
// Notification reasons to include in response.        @SerialName("reasons")
        val reasons: List<String>? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("priority")
        val priority: Boolean? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("seenAt")
        val seenAt: ATProtocolDate? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("notifications")
        val notifications: List<Notification>,        @SerialName("priority")
        val priority: Boolean? = null,        @SerialName("seenAt")
        val seenAt: ATProtocolDate? = null    )

        @Serializable
    data class Notification(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("author")
        val author: AppBskyActorDefs.Profileview,/** The reason why this notification was delivered - e.g. your post was liked, or you received a new follower. */        @SerialName("reason")
        val reason: String,        @SerialName("reasonSubject")
        val reasonSubject: ATProtocolURI?,        @SerialName("record")
        val record: JsonElement,        @SerialName("isRead")
        val isRead: Boolean,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#notification"
        }
    }

}

/**
 * Enumerate notifications for the requesting account. Requires auth.
 *
 * Endpoint: app.bsky.notification.listNotifications
 */
suspend fun ATProtoClient.App.Bsky.Notification.listnotifications(
parameters: AppBskyNotificationListnotifications.Parameters): ATProtoResponse<AppBskyNotificationListnotifications.Output> {
    val endpoint = "app.bsky.notification.listNotifications"

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
