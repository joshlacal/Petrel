// Lexicon: 1, ID: app.bsky.unspecced.getConfig
// Get miscellaneous runtime configuration.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGetconfig {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getConfig"

        @Serializable
    data class Output(
        @SerialName("checkEmailConfirmed")
        val checkEmailConfirmed: Boolean? = null,        @SerialName("liveNow")
        val liveNow: List<Livenowconfig>? = null    )

        @Serializable
    data class Livenowconfig(
        @SerialName("did")
        val did: DID,        @SerialName("domains")
        val domains: List<String>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#livenowconfig"
        }
    }

}

/**
 * Get miscellaneous runtime configuration.
 *
 * Endpoint: app.bsky.unspecced.getConfig
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getconfig(
): ATProtoResponse<AppBskyUnspeccedGetconfig.Output> {
    val endpoint = "app.bsky.unspecced.getConfig"

    val queryParams: Map<String, String>? = null

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
