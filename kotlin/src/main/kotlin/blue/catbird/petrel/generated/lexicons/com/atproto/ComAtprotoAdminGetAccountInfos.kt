// Lexicon: 1, ID: com.atproto.admin.getAccountInfos
// Get details about some accounts.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoAdminGetAccountInfosDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getAccountInfos"
}

@Serializable
    data class ComAtprotoAdminGetAccountInfosParameters(
        @SerialName("dids")
        val dids: List<DID>    )

    @Serializable
    data class ComAtprotoAdminGetAccountInfosOutput(
        @SerialName("infos")
        val infos: List<ComAtprotoAdminDefsAccountView>    )

/**
 * Get details about some accounts.
 *
 * Endpoint: com.atproto.admin.getAccountInfos
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getAccountInfos(
parameters: ComAtprotoAdminGetAccountInfosParameters): ATProtoResponse<ComAtprotoAdminGetAccountInfosOutput> {
    val endpoint = "com.atproto.admin.getAccountInfos"

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
