// Lexicon: 1, ID: com.atproto.simplespace.listMembers
// List the members in a space's host-internal member list. Must be called on the space authority's PDS. Requires OAuth with a covering read grant; a space credential is not sufficient, so members hosted elsewhere cannot enumerate the list. This reflects the simplespace member list, not a protocol-level reader set.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSimplespaceListMembersDefs {
    const val TYPE_IDENTIFIER = "com.atproto.simplespace.listMembers"
}

    @Serializable
    data class ComAtprotoSimplespaceListMembersMember(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSimplespaceListMembersMember"
        }
    }

@Serializable
    data class ComAtprotoSimplespaceListMembersParameters(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef,// Maximum number of members to return.        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ComAtprotoSimplespaceListMembersOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("members")
        val members: List<ComAtprotoSimplespaceListMembersMember>    )

sealed class ComAtprotoSimplespaceListMembersError(val name: String, val description: String?) {
        object SpaceNotFound: ComAtprotoSimplespaceListMembersError("SpaceNotFound", "")
    }

/**
 * List the members in a space's host-internal member list. Must be called on the space authority's PDS. Requires OAuth with a covering read grant; a space credential is not sufficient, so members hosted elsewhere cannot enumerate the list. This reflects the simplespace member list, not a protocol-level reader set.
 *
 * Endpoint: com.atproto.simplespace.listMembers
 */
suspend fun ATProtoClient.Com.Atproto.Simplespace.listMembers(
parameters: ComAtprotoSimplespaceListMembersParameters): ATProtoResponse<ComAtprotoSimplespaceListMembersOutput> {
    val endpoint = "com.atproto.simplespace.listMembers"

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
