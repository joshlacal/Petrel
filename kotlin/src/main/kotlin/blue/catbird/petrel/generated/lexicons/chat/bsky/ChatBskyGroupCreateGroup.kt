// Lexicon: 1, ID: chat.bsky.group.createGroup
// Creates a group convo, specifying the members to be added to it. Unlike getConvoForMembers, this isn't idempotent. It will create new groups even if the membership is identical to pre-existing groups. Will create 'request' membership for all members, except the owner who is 'accepted'.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupCreateGroupDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.createGroup"
}

@Serializable
    data class ChatBskyGroupCreateGroupInput(
        @SerialName("members")
        val members: List<DID>,        @SerialName("name")
        val name: String    )

    @Serializable
    data class ChatBskyGroupCreateGroupOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyGroupCreateGroupError(val name: String, val description: String?) {
        object AccountSuspended: ChatBskyGroupCreateGroupError("AccountSuspended", "")
        object BlockedActor: ChatBskyGroupCreateGroupError("BlockedActor", "")
        object BlockedSubject: ChatBskyGroupCreateGroupError("BlockedSubject", "")
        object NewAccountCannotCreateGroup: ChatBskyGroupCreateGroupError("NewAccountCannotCreateGroup", "")
        object NotFollowedBySender: ChatBskyGroupCreateGroupError("NotFollowedBySender", "")
        object RecipientNotFound: ChatBskyGroupCreateGroupError("RecipientNotFound", "")
        object UserForbidsGroups: ChatBskyGroupCreateGroupError("UserForbidsGroups", "")
    }

/**
 * Creates a group convo, specifying the members to be added to it. Unlike getConvoForMembers, this isn't idempotent. It will create new groups even if the membership is identical to pre-existing groups. Will create 'request' membership for all members, except the owner who is 'accepted'.
 *
 * Endpoint: chat.bsky.group.createGroup
 */
suspend fun ATProtoClient.Chat.Bsky.Group.createGroup(
input: ChatBskyGroupCreateGroupInput): ATProtoResponse<ChatBskyGroupCreateGroupOutput> {
    val endpoint = "chat.bsky.group.createGroup"

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
