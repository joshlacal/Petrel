// Lexicon: 1, ID: blue.catbird.mlsChat.getCommits
// Retrieve MLS commit messages for a conversation within an epoch range
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetCommitsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getCommits"
}

    /**
     * An MLS commit message with metadata
     */
    @Serializable
    data class BlueCatbirdMlsChatGetCommitsCommitMessage(
/** MLS epoch number for this commit */        @SerialName("epoch")
        val epoch: Int,/** DID of the member who created the commit (may include device fragment) */        @SerialName("sender")
        val sender: String,/** MLS commit message bytes */        @SerialName("commitData")
        val commitData: ByteArray?,/** Timestamp when commit was created */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetCommitsCommitMessage"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatGetCommitsParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Starting epoch number (inclusive)        @SerialName("fromEpoch")
        val fromEpoch: Int,// Ending epoch number (inclusive, optional - defaults to current epoch)        @SerialName("toEpoch")
        val toEpoch: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetCommitsOutput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// List of commit messages in the epoch range        @SerialName("commits")
        val commits: List<BlueCatbirdMlsChatGetCommitsCommitMessage>    )

sealed class BlueCatbirdMlsChatGetCommitsError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatGetCommitsError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatGetCommitsError("NotMember", "Caller is not a member of the conversation")
        object InvalidEpochRange: BlueCatbirdMlsChatGetCommitsError("InvalidEpochRange", "Invalid epoch range specified")
    }

/**
 * Retrieve MLS commit messages for a conversation within an epoch range
 *
 * Endpoint: blue.catbird.mlsChat.getCommits
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getCommits(
parameters: BlueCatbirdMlsChatGetCommitsParameters): ATProtoResponse<BlueCatbirdMlsChatGetCommitsOutput> {
    val endpoint = "blue.catbird.mlsChat.getCommits"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
