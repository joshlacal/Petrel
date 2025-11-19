// Lexicon: 1, ID: app.bsky.unspecced.getAgeAssuranceState
// Returns the current state of the age assurance process for an account. This is used to check if the user has completed age assurance or if further action is required.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGetageassurancestate {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getAgeAssuranceState"

        typealias Output = AppBskyUnspeccedDefs.Ageassurancestate

}

/**
 * Returns the current state of the age assurance process for an account. This is used to check if the user has completed age assurance or if further action is required.
 *
 * Endpoint: app.bsky.unspecced.getAgeAssuranceState
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getageassurancestate(
): ATProtoResponse<AppBskyUnspeccedGetageassurancestate.Output> {
    val endpoint = "app.bsky.unspecced.getAgeAssuranceState"

    val queryParams: Map<String, String>? = null

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
