// Lexicon: 1, ID: com.atproto.server.createInviteCodes
// Create invite codes.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoServerCreateInviteCodesDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.createInviteCodes"
}

    @Serializable
    data class ComAtprotoServerCreateInviteCodesAccountCodes(
        @SerialName("account")
        val account: String,        @SerialName("codes")
        val codes: List<String>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoServerCreateInviteCodesAccountCodes"
        }
    }

@Serializable
    data class ComAtprotoServerCreateInviteCodesInput(
        @SerialName("codeCount")
        val codeCount: Int,        @SerialName("useCount")
        val useCount: Int,        @SerialName("forAccounts")
        val forAccounts: List<DID>? = null    )

    @Serializable
    data class ComAtprotoServerCreateInviteCodesOutput(
        @SerialName("codes")
        val codes: List<ComAtprotoServerCreateInviteCodesAccountCodes>    )

/**
 * Create invite codes.
 *
 * Endpoint: com.atproto.server.createInviteCodes
 */
suspend fun ATProtoClient.Com.Atproto.Server.createInviteCodes(
input: ComAtprotoServerCreateInviteCodesInput): ATProtoResponse<ComAtprotoServerCreateInviteCodesOutput> {
    val endpoint = "com.atproto.server.createInviteCodes"

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
            "Accept" to "application/json"
        ),
        body = body
    )
}
