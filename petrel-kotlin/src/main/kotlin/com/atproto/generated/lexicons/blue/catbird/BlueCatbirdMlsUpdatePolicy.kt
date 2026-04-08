// Lexicon: 1, ID: blue.catbird.mls.updatePolicy
// Update conversation policy settings Update policy settings for a conversation. Only admins can update policies. At least one policy field must be provided.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsUpdatePolicyDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.updatePolicy"
}

    /**
     * View of conversation policy settings
     */
    @Serializable
    data class BlueCatbirdMlsUpdatePolicyPolicyView(
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
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsUpdatePolicyPolicyView"
        }
    }

@Serializable
    data class BlueCatbirdMlsUpdatePolicyInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Whether invite links are enabled for this conversation        @SerialName("allowInvites")
        val allowInvites: Boolean? = null,// Whether only admins can create invite links        @SerialName("adminOnlyInvites")
        val adminOnlyInvites: Boolean? = null,// Whether non-admin members can add other members        @SerialName("allowMemberAdd")
        val allowMemberAdd: Boolean? = null,// Whether non-admin members can remove other members        @SerialName("allowMemberRemove")
        val allowMemberRemove: Boolean? = null,// Whether new members require admin approval before joining        @SerialName("requireAdminApproval")
        val requireAdminApproval: Boolean? = null,// Maximum number of members allowed in this conversation        @SerialName("maxMembers")
        val maxMembers: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsUpdatePolicyOutput(
// Updated policy settings        @SerialName("policy")
        val policy: BlueCatbirdMlsUpdatePolicyPolicyView    )

sealed class BlueCatbirdMlsUpdatePolicyError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsUpdatePolicyError("Unauthorized", "Caller is not an admin of this conversation")
        object ConvoNotFound: BlueCatbirdMlsUpdatePolicyError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsUpdatePolicyError("NotMember", "Caller is not a member of this conversation")
        object NoFieldsProvided: BlueCatbirdMlsUpdatePolicyError("NoFieldsProvided", "At least one policy field must be provided")
        object InvalidMaxMembers: BlueCatbirdMlsUpdatePolicyError("InvalidMaxMembers", "maxMembers is less than current member count")
    }

/**
 * Update conversation policy settings Update policy settings for a conversation. Only admins can update policies. At least one policy field must be provided.
 *
 * Endpoint: blue.catbird.mls.updatePolicy
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.updatePolicy(
input: BlueCatbirdMlsUpdatePolicyInput): ATProtoResponse<BlueCatbirdMlsUpdatePolicyOutput> {
    val endpoint = "blue.catbird.mls.updatePolicy"

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
