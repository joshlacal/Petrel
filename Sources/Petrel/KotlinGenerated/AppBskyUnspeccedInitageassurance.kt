// Lexicon: 1, ID: app.bsky.unspecced.initAgeAssurance
// Initiate age assurance for an account. This is a one-time action that will start the process of verifying the user's age.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedInitageassurance {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.initAgeAssurance"

    @Serializable
    data class Input(
// The user's email address to receive assurance instructions.        @SerialName("email")
        val email: String,// The user's preferred language for communication during the assurance process.        @SerialName("language")
        val language: String,// An ISO 3166-1 alpha-2 code of the user's location.        @SerialName("countryCode")
        val countryCode: String    )

        typealias Output = AppBskyUnspeccedDefs.Ageassurancestate

    sealed class Error(val name: String, val description: String?) {
        object Invalidemail: Error("InvalidEmail", "")
        object Didtoolong: Error("DidTooLong", "")
        object Invalidinitiation: Error("InvalidInitiation", "")
    }

}

/**
 * Initiate age assurance for an account. This is a one-time action that will start the process of verifying the user's age.
 *
 * Endpoint: app.bsky.unspecced.initAgeAssurance
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.initageassurance(
input: AppBskyUnspeccedInitageassurance.Input): ATProtoResponse<AppBskyUnspeccedInitageassurance.Output> {
    val endpoint = "app.bsky.unspecced.initAgeAssurance"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
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
