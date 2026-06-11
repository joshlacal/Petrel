// Lexicon: 1, ID: com.atproto.admin.updateAccountEmail
// Administrative action to update an account's email.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoAdminUpdateAccountEmailDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.updateAccountEmail"
}

@Serializable
    data class ComAtprotoAdminUpdateAccountEmailInput(
// The handle or DID of the repo.        @SerialName("account")
        val account: ATIdentifier,        @SerialName("email")
        val email: String    )

/**
 * Administrative action to update an account's email.
 *
 * Endpoint: com.atproto.admin.updateAccountEmail
 */
suspend fun ATProtoClient.Com.Atproto.Admin.updateAccountEmail(
input: ComAtprotoAdminUpdateAccountEmailInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.updateAccountEmail"

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
