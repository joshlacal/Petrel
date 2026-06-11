// Lexicon: 1, ID: com.atproto.temp.requestPhoneVerification
// Request a verification code to be sent to the supplied phone number
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
