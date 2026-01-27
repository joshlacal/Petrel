// Lexicon: 1, ID: app.bsky.unspecced.getAgeAssuranceState
// Returns the current state of the age assurance process for an account. This is used to check if the user has completed age assurance or if further action is required.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetAgeAssuranceStateDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getAgeAssuranceState"
}

    typealias AppBskyUnspeccedGetAgeAssuranceStateOutput = AppBskyUnspeccedDefsAgeAssuranceState

/**
 * Returns the current state of the age assurance process for an account. This is used to check if the user has completed age assurance or if further action is required.
 *
 * Endpoint: app.bsky.unspecced.getAgeAssuranceState
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getAgeAssuranceState(
): ATProtoResponse<AppBskyUnspeccedGetAgeAssuranceStateOutput> {
    val endpoint = "app.bsky.unspecced.getAgeAssuranceState"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
