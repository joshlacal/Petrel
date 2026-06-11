// Lexicon: 1, ID: com.atproto.admin.updateAccountHandle
// Administrative action to update an account's handle.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoAdminUpdateAccountHandleDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.updateAccountHandle"
}

@Serializable
    data class ComAtprotoAdminUpdateAccountHandleInput(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle    )

/**
 * Administrative action to update an account's handle.
 *
 * Endpoint: com.atproto.admin.updateAccountHandle
 */
suspend fun ATProtoClient.Com.Atproto.Admin.updateAccountHandle(
input: ComAtprotoAdminUpdateAccountHandleInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.updateAccountHandle"

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
