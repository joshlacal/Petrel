// Lexicon: 1, ID: app.bsky.contact.startPhoneVerification
// Starts a phone verification flow. The phone passed will receive a code via SMS that should be passed to `app.bsky.contact.verifyPhone`. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyContactStartPhoneVerificationDefs {
    const val TYPE_IDENTIFIER = "app.bsky.contact.startPhoneVerification"
}

@Serializable
    data class AppBskyContactStartPhoneVerificationInput(
// The phone number to receive the code via SMS.        @SerialName("phone")
        val phone: String    )

    @Serializable
    class AppBskyContactStartPhoneVerificationOutput

sealed class AppBskyContactStartPhoneVerificationError(val name: String, val description: String?) {
        object RateLimitExceeded: AppBskyContactStartPhoneVerificationError("RateLimitExceeded", "")
        object InvalidDid: AppBskyContactStartPhoneVerificationError("InvalidDid", "")
        object InvalidPhone: AppBskyContactStartPhoneVerificationError("InvalidPhone", "")
        object InternalError: AppBskyContactStartPhoneVerificationError("InternalError", "")
    }

/**
 * Starts a phone verification flow. The phone passed will receive a code via SMS that should be passed to `app.bsky.contact.verifyPhone`. Requires authentication.
 *
 * Endpoint: app.bsky.contact.startPhoneVerification
 */
suspend fun ATProtoClient.App.Bsky.Contact.startPhoneVerification(
input: AppBskyContactStartPhoneVerificationInput): ATProtoResponse<AppBskyContactStartPhoneVerificationOutput> {
    val endpoint = "app.bsky.contact.startPhoneVerification"

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
