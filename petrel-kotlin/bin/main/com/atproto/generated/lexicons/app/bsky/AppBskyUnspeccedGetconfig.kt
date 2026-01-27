// Lexicon: 1, ID: app.bsky.unspecced.getConfig
// Get miscellaneous runtime configuration.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
