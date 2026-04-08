// Lexicon: 1, ID: app.bsky.actor.getProfile
// Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyActorGetProfileDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.getProfile"
}

@Serializable
    data class AppBskyActorGetProfileParameters(
// Handle or DID of account to fetch profile of.        @SerialName("actor")
        val actor: ATIdentifier    )

    typealias AppBskyActorGetProfileOutput = AppBskyActorDefsProfileViewDetailed

/**
 * Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.
 *
 * Endpoint: app.bsky.actor.getProfile
 */
suspend fun ATProtoClient.App.Bsky.Actor.getProfile(
parameters: AppBskyActorGetProfileParameters): ATProtoResponse<AppBskyActorGetProfileOutput> {
    val endpoint = "app.bsky.actor.getProfile"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
