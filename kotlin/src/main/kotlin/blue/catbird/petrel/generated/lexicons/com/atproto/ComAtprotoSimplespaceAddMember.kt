// Lexicon: 1, ID: com.atproto.simplespace.addMember
// Add a member to a space's member list. The member list is host-internal state consulted at credential-mint time when the space's policy is 'member-list'. It is not a synced protocol structure and is not enumerated to the network. Requires auth as the space owner.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSimplespaceAddMemberDefs {
    const val TYPE_IDENTIFIER = "com.atproto.simplespace.addMember"
}

@Serializable
    data class ComAtprotoSimplespaceAddMemberInput(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef,// The DID of the member to add.        @SerialName("did")
        val did: DID    )

sealed class ComAtprotoSimplespaceAddMemberError(val name: String, val description: String?) {
        object SpaceNotFound: ComAtprotoSimplespaceAddMemberError("SpaceNotFound", "")
        object NotSpaceOwner: ComAtprotoSimplespaceAddMemberError("NotSpaceOwner", "")
    }

/**
 * Add a member to a space's member list. The member list is host-internal state consulted at credential-mint time when the space's policy is 'member-list'. It is not a synced protocol structure and is not enumerated to the network. Requires auth as the space owner.
 *
 * Endpoint: com.atproto.simplespace.addMember
 */
suspend fun ATProtoClient.Com.Atproto.Simplespace.addMember(
input: ComAtprotoSimplespaceAddMemberInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.simplespace.addMember"

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
