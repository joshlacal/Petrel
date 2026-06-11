// Lexicon: 1, ID: com.atproto.admin.updateAccountSigningKey
// Administrative action to update an account's signing key in their Did document.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoAdminUpdateAccountSigningKeyDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.updateAccountSigningKey"
}

@Serializable
    data class ComAtprotoAdminUpdateAccountSigningKeyInput(
        @SerialName("did")
        val did: DID,// Did-key formatted public key        @SerialName("signingKey")
        val signingKey: DID    )

/**
 * Administrative action to update an account's signing key in their Did document.
 *
 * Endpoint: com.atproto.admin.updateAccountSigningKey
 */
suspend fun ATProtoClient.Com.Atproto.Admin.updateAccountSigningKey(
input: ComAtprotoAdminUpdateAccountSigningKeyInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.updateAccountSigningKey"

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
