// Lexicon: 1, ID: app.bsky.ageassurance.begin
// Initiate Age Assurance for an account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyAgeassuranceBeginDefs {
    const val TYPE_IDENTIFIER = "app.bsky.ageassurance.begin"
}

@Serializable
    data class AppBskyAgeassuranceBeginInput(
// The user's email address to receive Age Assurance instructions.        @SerialName("email")
        val email: String,// The user's preferred language for communication during the Age Assurance process.        @SerialName("language")
        val language: String,// An ISO 3166-1 alpha-2 code of the user's location.        @SerialName("countryCode")
        val countryCode: String,// An optional ISO 3166-2 code of the user's region or state within the country.        @SerialName("regionCode")
        val regionCode: String? = null    )

    typealias AppBskyAgeassuranceBeginOutput = AppBskyAgeassuranceDefsState

sealed class AppBskyAgeassuranceBeginError(val name: String, val description: String?) {
        object InvalidEmail: AppBskyAgeassuranceBeginError("InvalidEmail", "")
        object DidTooLong: AppBskyAgeassuranceBeginError("DidTooLong", "")
        object InvalidInitiation: AppBskyAgeassuranceBeginError("InvalidInitiation", "")
        object RegionNotSupported: AppBskyAgeassuranceBeginError("RegionNotSupported", "")
    }

/**
 * Initiate Age Assurance for an account.
 *
 * Endpoint: app.bsky.ageassurance.begin
 */
suspend fun ATProtoClient.App.Bsky.Ageassurance.begin(
input: AppBskyAgeassuranceBeginInput): ATProtoResponse<AppBskyAgeassuranceBeginOutput> {
    val endpoint = "app.bsky.ageassurance.begin"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
