// Lexicon: 1, ID: app.bsky.contact.sendNotification
// System endpoint to send notifications related to contact imports. Requires role authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyContactSendNotificationDefs {
    const val TYPE_IDENTIFIER = "app.bsky.contact.sendNotification"
}

@Serializable
    data class AppBskyContactSendNotificationInput(
// The DID of who this notification comes from.        @SerialName("from")
        val from: DID,// The DID of who this notification should go to.        @SerialName("to")
        val to: DID    )

    @Serializable
    class AppBskyContactSendNotificationOutput

/**
 * System endpoint to send notifications related to contact imports. Requires role authentication.
 *
 * Endpoint: app.bsky.contact.sendNotification
 */
suspend fun ATProtoClient.App.Bsky.Contact.sendNotification(
input: AppBskyContactSendNotificationInput): ATProtoResponse<AppBskyContactSendNotificationOutput> {
    val endpoint = "app.bsky.contact.sendNotification"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

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
