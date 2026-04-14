// Lexicon: 1, ID: app.bsky.contact.verifyPhone
// Verifies control over a phone number with a code received via SMS and starts a contact import session. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyContactVerifyPhoneDefs {
    const val TYPE_IDENTIFIER = "app.bsky.contact.verifyPhone"
}

@Serializable
    data class AppBskyContactVerifyPhoneInput(
// The phone number to verify. Should be the same as the one passed to `app.bsky.contact.startPhoneVerification`.        @SerialName("phone")
        val phone: String,// The code received via SMS as a result of the call to `app.bsky.contact.startPhoneVerification`.        @SerialName("code")
        val code: String    )

    @Serializable
    data class AppBskyContactVerifyPhoneOutput(
// JWT to be used in a call to `app.bsky.contact.importContacts`. It is only valid for a single call.        @SerialName("token")
        val token: String    )

sealed class AppBskyContactVerifyPhoneError(val name: String, val description: String?) {
        object RateLimitExceeded: AppBskyContactVerifyPhoneError("RateLimitExceeded", "")
        object InvalidDid: AppBskyContactVerifyPhoneError("InvalidDid", "")
        object InvalidPhone: AppBskyContactVerifyPhoneError("InvalidPhone", "")
        object InvalidCode: AppBskyContactVerifyPhoneError("InvalidCode", "")
        object InternalError: AppBskyContactVerifyPhoneError("InternalError", "")
    }

/**
 * Verifies control over a phone number with a code received via SMS and starts a contact import session. Requires authentication.
 *
 * Endpoint: app.bsky.contact.verifyPhone
 */
suspend fun ATProtoClient.App.Bsky.Contact.verifyPhone(
input: AppBskyContactVerifyPhoneInput): ATProtoResponse<AppBskyContactVerifyPhoneOutput> {
    val endpoint = "app.bsky.contact.verifyPhone"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
