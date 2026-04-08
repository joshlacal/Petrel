// Lexicon: 1, ID: blue.catbird.mlsChat.updateConvo
// Update conversation settings including admin/moderator management, policy, and group info
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatUpdateConvoDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.updateConvo"
}

    /**
     * Policy settings to update
     */
    @Serializable
    data class BlueCatbirdMlsChatUpdateConvoPolicyInput(
/** Allow members to join via external commits */        @SerialName("allowExternalCommits")
        val allowExternalCommits: Boolean?,/** Require an invite to join the conversation */        @SerialName("requireInviteForJoin")
        val requireInviteForJoin: Boolean?,/** Allow removed members to rejoin */        @SerialName("allowRejoin")
        val allowRejoin: Boolean?,/** Number of days a removed member can rejoin */        @SerialName("rejoinWindowDays")
        val rejoinWindowDays: Int?,/** Prevent removal of the last admin */        @SerialName("preventRemovingLastAdmin")
        val preventRemovingLastAdmin: Boolean?,/** Maximum number of members allowed */        @SerialName("maxMembers")
        val maxMembers: Int?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatUpdateConvoPolicyInput"
        }
    }

    /**
     * Current policy state
     */
    @Serializable
    data class BlueCatbirdMlsChatUpdateConvoPolicyView(
        @SerialName("allowExternalCommits")
        val allowExternalCommits: Boolean?,        @SerialName("requireInviteForJoin")
        val requireInviteForJoin: Boolean?,        @SerialName("allowRejoin")
        val allowRejoin: Boolean?,        @SerialName("rejoinWindowDays")
        val rejoinWindowDays: Int?,        @SerialName("preventRemovingLastAdmin")
        val preventRemovingLastAdmin: Boolean?,        @SerialName("maxMembers")
        val maxMembers: Int?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatUpdateConvoPolicyView"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatUpdateConvoInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Update action to perform        @SerialName("action")
        val action: String,// Target member DID for promote/demote actions        @SerialName("targetDid")
        val targetDid: DID? = null,// Policy object for updatePolicy action        @SerialName("policy")
        val policy: BlueCatbirdMlsChatUpdateConvoPolicyInput? = null,// MLS group info bytes for updateGroupInfo action        @SerialName("groupInfo")
        val groupInfo: ByteArray? = null,// Expected epoch for optimistic concurrency        @SerialName("epoch")
        val epoch: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatUpdateConvoOutput(
// Whether the update was successful        @SerialName("success")
        val success: Boolean,// New epoch number after the update        @SerialName("newEpoch")
        val newEpoch: Int? = null,// Updated policy view        @SerialName("policy")
        val policy: BlueCatbirdMlsChatUpdateConvoPolicyView? = null    )

sealed class BlueCatbirdMlsChatUpdateConvoError(val name: String, val description: String?) {
        object InvalidRequest: BlueCatbirdMlsChatUpdateConvoError("InvalidRequest", "Invalid request parameters")
        object Unauthorized: BlueCatbirdMlsChatUpdateConvoError("Unauthorized", "Authentication required")
        object Forbidden: BlueCatbirdMlsChatUpdateConvoError("Forbidden", "User does not have permission for this action")
        object NotFound: BlueCatbirdMlsChatUpdateConvoError("NotFound", "Conversation not found")
    }

/**
 * Update conversation settings including admin/moderator management, policy, and group info
 *
 * Endpoint: blue.catbird.mlsChat.updateConvo
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.updateConvo(
input: BlueCatbirdMlsChatUpdateConvoInput): ATProtoResponse<BlueCatbirdMlsChatUpdateConvoOutput> {
    val endpoint = "blue.catbird.mlsChat.updateConvo"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
