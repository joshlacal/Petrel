// Lexicon: 1, ID: app.bsky.actor.getProfiles
// Get detailed profile views of multiple actors.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyActorGetprofiles {
    const val TYPE_IDENTIFIER = "app.bsky.actor.getProfiles"

    @Serializable
    data class Parameters(
        @SerialName("actors")
        val actors: List<ATIdentifier>    )

        @Serializable
    data class Output(
        @SerialName("profiles")
        val profiles: List<AppBskyActorDefs.Profileviewdetailed>    )

}

/**
 * Get detailed profile views of multiple actors.
 *
 * Endpoint: app.bsky.actor.getProfiles
 */
suspend fun ATProtoClient.App.Bsky.Actor.getprofiles(
parameters: AppBskyActorGetprofiles.Parameters): ATProtoResponse<AppBskyActorGetprofiles.Output> {
    val endpoint = "app.bsky.actor.getProfiles"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
