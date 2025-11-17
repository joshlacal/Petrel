// Lexicon: 1, ID: com.atproto.sync.requestCrawl
// Request a service to persistently crawl hosted repos. Expected use is new PDS instances declaring their existence to Relays. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncRequestcrawl {
    const val TYPE_IDENTIFIER = "com.atproto.sync.requestCrawl"

    @Serializable
    data class Input(
// Hostname of the current service (eg, PDS) that is requesting to be crawled.        @SerialName("hostname")
        val hostname: String    )

    sealed class Error(val name: String, val description: String?) {
        object Hostbanned: Error("HostBanned", "")
    }

}

/**
 * Request a service to persistently crawl hosted repos. Expected use is new PDS instances declaring their existence to Relays. Does not require auth.
 *
 * Endpoint: com.atproto.sync.requestCrawl
 */
suspend fun ATProtoClient.Com.Atproto.Sync.requestcrawl(
input: ComAtprotoSyncRequestcrawl.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.sync.requestCrawl"

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
