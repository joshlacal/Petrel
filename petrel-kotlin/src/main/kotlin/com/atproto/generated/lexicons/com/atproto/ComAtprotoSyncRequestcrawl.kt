// Lexicon: 1, ID: com.atproto.sync.requestCrawl
// Request a service to persistently crawl hosted repos. Expected use is new PDS instances declaring their existence to Relays. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncRequestCrawlDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.requestCrawl"
}

@Serializable
    data class ComAtprotoSyncRequestCrawlInput(
// Hostname of the current service (eg, PDS) that is requesting to be crawled.        @SerialName("hostname")
        val hostname: String    )

sealed class ComAtprotoSyncRequestCrawlError(val name: String, val description: String?) {
        object HostBanned: ComAtprotoSyncRequestCrawlError("HostBanned", "")
    }

/**
 * Request a service to persistently crawl hosted repos. Expected use is new PDS instances declaring their existence to Relays. Does not require auth.
 *
 * Endpoint: com.atproto.sync.requestCrawl
 */
suspend fun ATProtoClient.Com.Atproto.Sync.requestCrawl(
input: ComAtprotoSyncRequestCrawlInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.sync.requestCrawl"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
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
