// Lexicon: 1, ID: blue.catbird.mlsChat.updatePolicy
// Update conversation policy settings Update policy settings for a conversation. Only admins can update policies. At least one policy field must be provided.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatUpdatePolicyDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.updatePolicy"
}

    /**
     * View of conversation policy settings
     */
    @Serializable
    data class BlueCatbirdMlsChatUpdatePolicyPolicyView(
/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Whether invite links are enabled for this conversation */        @SerialName("allowInvites")
        val allowInvites: Boolean,/** Whether only admins can create invite links */        @SerialName("adminOnlyInvites")
        val adminOnlyInvites: Boolean,/** Whether non-admin members can add other members */        @SerialName("allowMemberAdd")
        val allowMemberAdd: Boolean,/** Whether non-admin members can remove other members */        @SerialName("allowMemberRemove")
        val allowMemberRemove: Boolean,/** Whether new members require admin approval before joining */        @SerialName("requireAdminApproval")
        val requireAdminApproval: Boolean,/** Maximum number of members allowed in this conversation */        @SerialName("maxMembers")
        val maxMembers: Int,/** Timestamp of last policy update */        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate,/** DID of admin who last updated the policy */        @SerialName("updatedBy")
        val updatedBy: DID?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatUpdatePolicyPolicyView"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatUpdatePolicyInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Whether invite links are enabled for this conversation        @SerialName("allowInvites")
        val allowInvites: Boolean? = null,// Whether only admins can create invite links        @SerialName("adminOnlyInvites")
        val adminOnlyInvites: Boolean? = null,// Whether non-admin members can add other members        @SerialName("allowMemberAdd")
        val allowMemberAdd: Boolean? = null,// Whether non-admin members can remove other members        @SerialName("allowMemberRemove")
        val allowMemberRemove: Boolean? = null,// Whether new members require admin approval before joining        @SerialName("requireAdminApproval")
        val requireAdminApproval: Boolean? = null,// Maximum number of members allowed in this conversation        @SerialName("maxMembers")
        val maxMembers: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatUpdatePolicyOutput(
// Updated policy settings        @SerialName("policy")
        val policy: BlueCatbirdMlsChatUpdatePolicyPolicyView    )

sealed class BlueCatbirdMlsChatUpdatePolicyError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatUpdatePolicyError("Unauthorized", "Caller is not an admin of this conversation")
        object ConvoNotFound: BlueCatbirdMlsChatUpdatePolicyError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatUpdatePolicyError("NotMember", "Caller is not a member of this conversation")
        object NoFieldsProvided: BlueCatbirdMlsChatUpdatePolicyError("NoFieldsProvided", "At least one policy field must be provided")
        object InvalidMaxMembers: BlueCatbirdMlsChatUpdatePolicyError("InvalidMaxMembers", "maxMembers is less than current member count")
    }

/**
 * Update conversation policy settings Update policy settings for a conversation. Only admins can update policies. At least one policy field must be provided.
 *
 * Endpoint: blue.catbird.mlsChat.updatePolicy
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.updatePolicy(
input: BlueCatbirdMlsChatUpdatePolicyInput): ATProtoResponse<BlueCatbirdMlsChatUpdatePolicyOutput> {
    val endpoint = "blue.catbird.mlsChat.updatePolicy"

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
