// Lexicon: 1, ID: place.stream.config.getEnv
// Get client-facing environment configuration from the server.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamConfigGetEnvDefs {
    const val TYPE_IDENTIFIER = "place.stream.config.getEnv"
}

@Serializable
    class PlaceStreamConfigGetEnvParameters

    @Serializable
    data class PlaceStreamConfigGetEnvOutput(
// URL of the Cloudflare playback router worker        @SerialName("playbackWorkerUrl")
        val playbackWorkerUrl: String? = null    )

/**
 * Get client-facing environment configuration from the server.
 *
 * Endpoint: place.stream.config.getEnv
 */
suspend fun ATProtoClient.Place.Stream.Config.getEnv(
parameters: PlaceStreamConfigGetEnvParameters): ATProtoResponse<PlaceStreamConfigGetEnvOutput> {
    val endpoint = "place.stream.config.getEnv"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
