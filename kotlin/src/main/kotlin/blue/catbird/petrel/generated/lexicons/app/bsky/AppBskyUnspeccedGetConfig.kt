// Lexicon: 1, ID: app.bsky.unspecced.getConfig
// Get miscellaneous runtime configuration.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetConfigDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getConfig"
}

    @Serializable
    data class AppBskyUnspeccedGetConfigLiveNowConfig(
        @SerialName("did")
        val did: DID,        @SerialName("domains")
        val domains: List<String>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyUnspeccedGetConfigLiveNowConfig"
        }
    }

    @Serializable
    data class AppBskyUnspeccedGetConfigOutput(
        @SerialName("checkEmailConfirmed")
        val checkEmailConfirmed: Boolean? = null,        @SerialName("liveNow")
        val liveNow: List<AppBskyUnspeccedGetConfigLiveNowConfig>? = null    )

/**
 * Get miscellaneous runtime configuration.
 *
 * Endpoint: app.bsky.unspecced.getConfig
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getConfig(
): ATProtoResponse<AppBskyUnspeccedGetConfigOutput> {
    val endpoint = "app.bsky.unspecced.getConfig"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
