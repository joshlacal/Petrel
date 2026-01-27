// Lexicon: 1, ID: blue.catbird.mls.getCommits
// Retrieve MLS commit messages for a conversation within an epoch range
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetCommitsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getCommits"
}

    /**
     * An MLS commit message with metadata
     */
    @Serializable
    data class BlueCatbirdMlsGetCommitsCommitMessage(
/** MLS epoch number for this commit */        @SerialName("epoch")
        val epoch: Int,/** DID of the member who created the commit */        @SerialName("sender")
        val sender: DID,/** MLS commit message bytes */        @SerialName("commitData")
        val commitData: ByteArray,/** Timestamp when commit was created */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsGetCommitsCommitMessage"
        }
    }

@Serializable
    data class BlueCatbirdMlsGetCommitsParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Starting epoch number (inclusive)        @SerialName("fromEpoch")
        val fromEpoch: Int,// Ending epoch number (inclusive, optional - defaults to current epoch)        @SerialName("toEpoch")
        val toEpoch: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsGetCommitsOutput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// List of commit messages in the epoch range        @SerialName("commits")
        val commits: List<BlueCatbirdMlsGetCommitsCommitMessage>    )

sealed class BlueCatbirdMlsGetCommitsError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsGetCommitsError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsGetCommitsError("NotMember", "Caller is not a member of the conversation")
        object InvalidEpochRange: BlueCatbirdMlsGetCommitsError("InvalidEpochRange", "Invalid epoch range specified")
    }

/**
 * Retrieve MLS commit messages for a conversation within an epoch range
 *
 * Endpoint: blue.catbird.mls.getCommits
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getCommits(
parameters: BlueCatbirdMlsGetCommitsParameters): ATProtoResponse<BlueCatbirdMlsGetCommitsOutput> {
    val endpoint = "blue.catbird.mls.getCommits"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
