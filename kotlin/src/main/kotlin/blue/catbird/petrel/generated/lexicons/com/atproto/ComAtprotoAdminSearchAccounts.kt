// Lexicon: 1, ID: com.atproto.admin.searchAccounts
// Get list of accounts that matches your search query.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoAdminSearchAccountsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.searchAccounts"
}

@Serializable
    data class ComAtprotoAdminSearchAccountsParameters(
        @SerialName("email")
        val email: String? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class ComAtprotoAdminSearchAccountsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("accounts")
        val accounts: List<ComAtprotoAdminDefsAccountView>    )

/**
 * Get list of accounts that matches your search query.
 *
 * Endpoint: com.atproto.admin.searchAccounts
 */
suspend fun ATProtoClient.Com.Atproto.Admin.searchAccounts(
parameters: ComAtprotoAdminSearchAccountsParameters): ATProtoResponse<ComAtprotoAdminSearchAccountsOutput> {
    val endpoint = "com.atproto.admin.searchAccounts"

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
