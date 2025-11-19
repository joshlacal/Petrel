// Lexicon: 1, ID: app.bsky.actor.getProfile
// Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyActorGetprofile {
    const val TYPE_IDENTIFIER = "app.bsky.actor.getProfile"

    @Serializable
    data class Parameters(
// Handle or DID of account to fetch profile of.        @SerialName("actor")
        val actor: ATIdentifier    )

        typealias Output = AppBskyActorDefs.Profileviewdetailed

}

/**
 * Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.
 *
 * Endpoint: app.bsky.actor.getProfile
 */
suspend fun ATProtoClient.App.Bsky.Actor.getprofile(
parameters: AppBskyActorGetprofile.Parameters): ATProtoResponse<AppBskyActorGetprofile.Output> {
    val endpoint = "app.bsky.actor.getProfile"

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
