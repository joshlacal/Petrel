// Lexicon: 1, ID: com.atproto.admin.getInviteCodes
// Get an admin view of invite codes.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoAdminGetInviteCodesDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getInviteCodes"
}

@Serializable
    data class ComAtprotoAdminGetInviteCodesParameters(
        @SerialName("sort")
        val sort: String? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ComAtprotoAdminGetInviteCodesOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("codes")
        val codes: List<ComAtprotoServerDefsInviteCode>    )

/**
 * Get an admin view of invite codes.
 *
 * Endpoint: com.atproto.admin.getInviteCodes
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getInviteCodes(
parameters: ComAtprotoAdminGetInviteCodesParameters): ATProtoResponse<ComAtprotoAdminGetInviteCodesOutput> {
    val endpoint = "com.atproto.admin.getInviteCodes"

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
