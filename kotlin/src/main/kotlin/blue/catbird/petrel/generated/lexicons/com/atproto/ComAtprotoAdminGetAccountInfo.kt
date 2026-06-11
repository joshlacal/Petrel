// Lexicon: 1, ID: com.atproto.admin.getAccountInfo
// Get details about an account.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoAdminGetAccountInfoDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getAccountInfo"
}

@Serializable
    data class ComAtprotoAdminGetAccountInfoParameters(
        @SerialName("did")
        val did: DID    )

    typealias ComAtprotoAdminGetAccountInfoOutput = ComAtprotoAdminDefsAccountView

/**
 * Get details about an account.
 *
 * Endpoint: com.atproto.admin.getAccountInfo
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getAccountInfo(
parameters: ComAtprotoAdminGetAccountInfoParameters): ATProtoResponse<ComAtprotoAdminGetAccountInfoOutput> {
    val endpoint = "com.atproto.admin.getAccountInfo"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
