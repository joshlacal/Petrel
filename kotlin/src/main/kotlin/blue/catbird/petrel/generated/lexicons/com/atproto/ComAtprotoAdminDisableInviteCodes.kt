// Lexicon: 1, ID: com.atproto.admin.disableInviteCodes
// Disable some set of codes and/or all codes associated with a set of users.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoAdminDisableInviteCodesDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.disableInviteCodes"
}

@Serializable
    data class ComAtprotoAdminDisableInviteCodesInput(
        @SerialName("codes")
        val codes: List<String>? = null,        @SerialName("accounts")
        val accounts: List<String>? = null    )

/**
 * Disable some set of codes and/or all codes associated with a set of users.
 *
 * Endpoint: com.atproto.admin.disableInviteCodes
 */
suspend fun ATProtoClient.Com.Atproto.Admin.disableInviteCodes(
input: ComAtprotoAdminDisableInviteCodesInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.disableInviteCodes"

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
