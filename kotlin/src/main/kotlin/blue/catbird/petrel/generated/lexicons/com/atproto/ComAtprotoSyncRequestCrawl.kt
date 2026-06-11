// Lexicon: 1, ID: com.atproto.sync.requestCrawl
// Request a service to persistently crawl hosted repos. Expected use is new PDS instances declaring their existence to Relays. Does not require auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
