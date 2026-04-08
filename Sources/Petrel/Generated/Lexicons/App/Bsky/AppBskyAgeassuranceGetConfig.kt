// Lexicon: 1, ID: app.bsky.ageassurance.getConfig
// Returns Age Assurance configuration for use on the client.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyAgeassuranceGetConfigDefs {
    const val TYPE_IDENTIFIER = "app.bsky.ageassurance.getConfig"
}

    typealias AppBskyAgeassuranceGetConfigOutput = AppBskyAgeassuranceDefsConfig

/**
 * Returns Age Assurance configuration for use on the client.
 *
 * Endpoint: app.bsky.ageassurance.getConfig
 */
suspend fun ATProtoClient.App.Bsky.Ageassurance.getConfig(
): ATProtoResponse<AppBskyAgeassuranceGetConfigOutput> {
    val endpoint = "app.bsky.ageassurance.getConfig"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
