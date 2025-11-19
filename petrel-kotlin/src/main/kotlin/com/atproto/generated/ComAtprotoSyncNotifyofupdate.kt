// Lexicon: 1, ID: com.atproto.sync.notifyOfUpdate
// Notify a crawling service of a recent update, and that crawling should resume. Intended use is after a gap between repo stream events caused the crawling service to disconnect. Does not require auth; implemented by Relay. DEPRECATED: just use com.atproto.sync.requestCrawl
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncNotifyofupdate {
    const val TYPE_IDENTIFIER = "com.atproto.sync.notifyOfUpdate"

    @Serializable
    data class Input(
// Hostname of the current service (usually a PDS) that is notifying of update.        @SerialName("hostname")
        val hostname: String    )

}

/**
 * Notify a crawling service of a recent update, and that crawling should resume. Intended use is after a gap between repo stream events caused the crawling service to disconnect. Does not require auth; implemented by Relay. DEPRECATED: just use com.atproto.sync.requestCrawl
 *
 * Endpoint: com.atproto.sync.notifyOfUpdate
 */
suspend fun ATProtoClient.Com.Atproto.Sync.notifyofupdate(
input: ComAtprotoSyncNotifyofupdate.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.sync.notifyOfUpdate"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
