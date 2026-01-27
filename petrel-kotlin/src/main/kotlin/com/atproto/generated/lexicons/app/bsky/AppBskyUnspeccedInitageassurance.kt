// Lexicon: 1, ID: app.bsky.unspecced.initAgeAssurance
// Initiate age assurance for an account. This is a one-time action that will start the process of verifying the user's age.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedInitAgeAssuranceDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.initAgeAssurance"
}

@Serializable
    data class AppBskyUnspeccedInitAgeAssuranceInput(
// The user's email address to receive assurance instructions.        @SerialName("email")
        val email: String,// The user's preferred language for communication during the assurance process.        @SerialName("language")
        val language: String,// An ISO 3166-1 alpha-2 code of the user's location.        @SerialName("countryCode")
        val countryCode: String    )

    typealias AppBskyUnspeccedInitAgeAssuranceOutput = AppBskyUnspeccedDefsAgeAssuranceState

sealed class AppBskyUnspeccedInitAgeAssuranceError(val name: String, val description: String?) {
        object InvalidEmail: AppBskyUnspeccedInitAgeAssuranceError("InvalidEmail", "")
        object DidTooLong: AppBskyUnspeccedInitAgeAssuranceError("DidTooLong", "")
        object InvalidInitiation: AppBskyUnspeccedInitAgeAssuranceError("InvalidInitiation", "")
    }

/**
 * Initiate age assurance for an account. This is a one-time action that will start the process of verifying the user's age.
 *
 * Endpoint: app.bsky.unspecced.initAgeAssurance
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.initAgeAssurance(
input: AppBskyUnspeccedInitAgeAssuranceInput): ATProtoResponse<AppBskyUnspeccedInitAgeAssuranceOutput> {
    val endpoint = "app.bsky.unspecced.initAgeAssurance"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
