// Lexicon: 1, ID: blue.catbird.mlsChat.updateConvo
// Update conversation settings (consolidates updatePolicy + promoteAdmin + demoteAdmin + promoteModerator + demoteModerator + updateGroupInfo + groupInfoRefresh) Perform administrative actions on a conversation. The 'action' field determines the operation. Most actions require admin privileges.
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
     * Policy settings to update (at least one field required)
     */
    @Serializable
    data class BlueCatbirdMlsChatUpdateConvoPolicyInput(
/** Whether invite links are enabled */        @SerialName("allowInvites")
        val allowInvites: Boolean? = null,/** Whether only admins can create invite links */        @SerialName("adminOnlyInvites")
        val adminOnlyInvites: Boolean? = null,/** Whether non-admin members can add other members */        @SerialName("allowMemberAdd")
        val allowMemberAdd: Boolean? = null,/** Whether non-admin members can remove other members */        @SerialName("allowMemberRemove")
        val allowMemberRemove: Boolean? = null,/** Whether new members require admin approval */        @SerialName("requireAdminApproval")
        val requireAdminApproval: Boolean? = null,/** Maximum number of members allowed */        @SerialName("maxMembers")
        val maxMembers: Int? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatUpdateConvoPolicyInput"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatUpdateConvoPolicyView(
/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,        @SerialName("allowInvites")
        val allowInvites: Boolean,        @SerialName("adminOnlyInvites")
        val adminOnlyInvites: Boolean,        @SerialName("allowMemberAdd")
        val allowMemberAdd: Boolean,        @SerialName("allowMemberRemove")
        val allowMemberRemove: Boolean,        @SerialName("requireAdminApproval")
        val requireAdminApproval: Boolean,        @SerialName("maxMembers")
        val maxMembers: Int,/** Timestamp of last policy update */        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate,/** DID of admin who last updated the policy */        @SerialName("updatedBy")
        val updatedBy: DID? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatUpdateConvoPolicyView"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatUpdateConvoInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Action to perform on the conversation        @SerialName("action")
        val action: String,// Target member DID (required for promote/demote actions)        @SerialName("targetDid")
        val targetDid: DID? = null,// Policy settings to update (required for 'updatePolicy' action)        @SerialName("policy")
        val policy: BlueCatbirdMlsChatUpdateConvoPolicyInput? = null,// Serialized GroupInfo bytes (required for 'updateGroupInfo' action)        @SerialName("groupInfo")
        val groupInfo: Bytes? = null,// MLS epoch the GroupInfo corresponds to (required for 'updateGroupInfo' action)        @SerialName("epoch")
        val epoch: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatUpdateConvoOutput(
// Whether the operation succeeded        @SerialName("success")
        val success: Boolean,// New epoch number (if the action caused an epoch change)        @SerialName("newEpoch")
        val newEpoch: Int? = null,// Updated policy settings (present when action is 'updatePolicy')        @SerialName("policy")
        val policy: BlueCatbirdMlsChatUpdateConvoPolicyView? = null    )

sealed class BlueCatbirdMlsChatUpdateConvoError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatUpdateConvoError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatUpdateConvoError("NotMember", "Caller is not a member of this conversation")
        object Unauthorized: BlueCatbirdMlsChatUpdateConvoError("Unauthorized", "Caller does not have required admin/moderator privileges")
        object InvalidAction: BlueCatbirdMlsChatUpdateConvoError("InvalidAction", "Unknown action value")
        object MissingTargetDid: BlueCatbirdMlsChatUpdateConvoError("MissingTargetDid", "targetDid is required for promote/demote actions")
        object TargetNotMember: BlueCatbirdMlsChatUpdateConvoError("TargetNotMember", "Target DID is not a member of the conversation")
        object NoFieldsProvided: BlueCatbirdMlsChatUpdateConvoError("NoFieldsProvided", "At least one policy field must be provided for updatePolicy")
        object InvalidGroupInfo: BlueCatbirdMlsChatUpdateConvoError("InvalidGroupInfo", "Provided GroupInfo is invalid or malformed")
        object InvalidMaxMembers: BlueCatbirdMlsChatUpdateConvoError("InvalidMaxMembers", "maxMembers is less than current member count")
    }

/**
 * Update conversation settings (consolidates updatePolicy + promoteAdmin + demoteAdmin + promoteModerator + demoteModerator + updateGroupInfo + groupInfoRefresh) Perform administrative actions on a conversation. The 'action' field determines the operation. Most actions require admin privileges.
 *
 * Endpoint: blue.catbird.mlsChat.updateConvo
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.updateConvo(
input: BlueCatbirdMlsChatUpdateConvoInput): ATProtoResponse<BlueCatbirdMlsChatUpdateConvoOutput> {
    val endpoint = "blue.catbird.mlsChat.updateConvo"

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
