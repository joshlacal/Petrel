// Lexicon: 1, ID: com.atproto.temp.requestPhoneVerification
// Request a verification code to be sent to the supplied phone number
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoTempRequestPhoneVerificationDefs {
    const val TYPE_IDENTIFIER = "com.atproto.temp.requestPhoneVerification"
}

@Serializable
    data class ComAtprotoTempRequestPhoneVerificationInput(
        @SerialName("phoneNumber")
        val phoneNumber: String    )

/**
 * Request a verification code to be sent to the supplied phone number
 *
 * Endpoint: com.atproto.temp.requestPhoneVerification
 */
suspend fun ATProtoClient.Com.Atproto.Temp.requestPhoneVerification(
input: ComAtprotoTempRequestPhoneVerificationInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.temp.requestPhoneVerification"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
