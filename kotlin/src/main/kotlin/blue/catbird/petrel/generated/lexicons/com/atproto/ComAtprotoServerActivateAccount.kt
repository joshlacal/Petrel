// Lexicon: 1, ID: com.atproto.server.activateAccount
// Activates a currently deactivated account. Used to finalize account migration after the account's repo is imported and identity is setup.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoServerActivateAccountDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.activateAccount"
}

/**
 * Activates a currently deactivated account. Used to finalize account migration after the account's repo is imported and identity is setup.
 *
 * Endpoint: com.atproto.server.activateAccount
 */
suspend fun ATProtoClient.Com.Atproto.Server.activateAccount(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.activateAccount"

    val body: String? = null
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
