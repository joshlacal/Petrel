// Lexicon: 1, ID: app.bsky.actor.getProfiles
// Get detailed profile views of multiple actors.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyActorGetProfilesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.getProfiles"
}

@Serializable
    data class AppBskyActorGetProfilesParameters(
        @SerialName("actors")
        val actors: List<ATIdentifier>    )

    @Serializable
    data class AppBskyActorGetProfilesOutput(
        @SerialName("profiles")
        val profiles: List<AppBskyActorDefsProfileViewDetailed>    )

/**
 * Get detailed profile views of multiple actors.
 *
 * Endpoint: app.bsky.actor.getProfiles
 */
suspend fun ATProtoClient.App.Bsky.Actor.getProfiles(
parameters: AppBskyActorGetProfilesParameters): ATProtoResponse<AppBskyActorGetProfilesOutput> {
    val endpoint = "app.bsky.actor.getProfiles"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
