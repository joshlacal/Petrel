package com.atproto.runtime.subscription

import com.atproto.client.ATProtoClient
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.client.plugins.websocket.webSocket
import io.ktor.websocket.Frame
import io.ktor.websocket.readBytes
import io.ktor.websocket.readText
import java.net.URLEncoder
import java.util.logging.Logger

/**
 * Shared WebSocket transport for ATProto subscription endpoints.
 *
 * Generated subscription functions call this helper to avoid duplicating URL
 * construction, ktor plumbing, and frame dispatch across every subscription
 * lexicon. The function is generic over the concrete message-union type —
 * the caller provides a [onFrame] callback that dispatches on `CborFrame.Message`
 * header tags and decodes the payload.
 */

private val transportLogger = Logger.getLogger("com.atproto.runtime.subscription.SubscriptionTransport")

/**
 * Open a WebSocket to [endpoint] and stream frames until the connection
 * closes. This is a `suspend` function, not a [kotlinx.coroutines.flow.Flow];
 * callers wrap it in `flow { ... }` so cancellation of the outer flow cancels
 * the underlying WebSocket coroutine.
 *
 * @param endpoint  XRPC NSID (e.g. `blue.catbird.mlsChat.subscribeEvents`).
 * @param queryItems Query string as ordered (key, value) pairs. Keys may repeat
 *                   for array-valued ATProto params; empty values are skipped.
 * @param hostOverride Optional fully-qualified ws/wss URL (used for custom
 *                     delivery services). If `null`, derives wss host from the
 *                     client's configured base URL.
 * @param websocketClient Optional pre-configured ktor [HttpClient]. If `null`,
 *                         a default CIO engine with the WebSockets plugin is
 *                         created and closed when the call returns.
 * @param onFrame Callback invoked for every successfully parsed [CborFrame].
 *                `null` parse results (malformed / ignored frames) are dropped
 *                without calling this.
 */
suspend fun ATProtoClient.openSubscription(
    endpoint: String,
    queryItems: List<Pair<String, String>>,
    hostOverride: String?,
    websocketClient: HttpClient?,
    onFrame: suspend (CborFrame) -> Unit,
) {
    val wsUrl = buildSubscriptionUrl(
        baseUrl = networkService.getBaseUrl(),
        endpoint = endpoint,
        queryItems = queryItems,
        hostOverride = hostOverride,
    )

    val wsClient = websocketClient ?: createDefaultSubscriptionClient()
    try {
        wsClient.webSocket(wsUrl) {
            for (frame in incoming) {
                when (frame) {
                    is Frame.Binary -> {
                        val parsed = parseBinaryFrame(frame.readBytes())
                        if (parsed != null) onFrame(parsed)
                    }
                    is Frame.Text -> {
                        // ATProto subscriptions are binary, but some test stubs
                        // and error surfaces send text. Log and skip.
                        transportLogger.fine("Ignoring text frame: ${frame.readText()}")
                    }
                    else -> {
                        // ping / pong / close — ktor handles these internally.
                    }
                }
            }
        }
    } finally {
        if (websocketClient == null) {
            wsClient.close()
        }
    }
}

/**
 * Assemble the full `wss://…/xrpc/<endpoint>?…` URL.
 *
 * If [hostOverride] is a full URL (includes scheme), it is used verbatim as
 * the base; otherwise the client's base URL has its scheme rewritten to `wss`
 * (or `ws` for `http://`) and `/xrpc/<endpoint>` appended.
 */
internal fun buildSubscriptionUrl(
    baseUrl: String,
    endpoint: String,
    queryItems: List<Pair<String, String>>,
    hostOverride: String?,
): String {
    val host = when {
        hostOverride != null && (hostOverride.startsWith("ws://") || hostOverride.startsWith("wss://")) ->
            hostOverride.trimEnd('/')
        hostOverride != null && (hostOverride.startsWith("http://") || hostOverride.startsWith("https://")) ->
            hostOverride.replaceFirst("http", "ws").trimEnd('/')
        hostOverride != null -> "wss://${hostOverride.trimEnd('/')}"
        else -> baseUrl
            .replaceFirst("https://", "wss://")
            .replaceFirst("http://", "ws://")
            .trimEnd('/')
    }

    val path = if (host.contains("/xrpc/")) "" else "/xrpc/$endpoint"

    val query = if (queryItems.isEmpty()) "" else buildString {
        append('?')
        queryItems.forEachIndexed { i, (k, v) ->
            if (i > 0) append('&')
            append(URLEncoder.encode(k, Charsets.UTF_8))
            append('=')
            append(URLEncoder.encode(v, Charsets.UTF_8))
        }
    }

    return "$host$path$query"
}

private fun createDefaultSubscriptionClient(): HttpClient =
    HttpClient(CIO) {
        install(WebSockets) {
            pingIntervalMillis = 30_000
        }
    }
