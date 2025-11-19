// Lexicon: 1, ID: com.atproto.repo.applyWrites
// Apply a batch transaction of repository creates, updates, and deletes. Requires auth, implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface InputWritesUnion {
    @Serializable
    @SerialName("com.atproto.repo.applyWrites#Create")
    data class Create(val value: Create) : InputWritesUnion

    @Serializable
    @SerialName("com.atproto.repo.applyWrites#Update")
    data class Update(val value: Update) : InputWritesUnion

    @Serializable
    @SerialName("com.atproto.repo.applyWrites#Delete")
    data class Delete(val value: Delete) : InputWritesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : InputWritesUnion
}

@Serializable
sealed interface OutputResultsUnion {
    @Serializable
    @SerialName("com.atproto.repo.applyWrites#Createresult")
    data class Createresult(val value: Createresult) : OutputResultsUnion

    @Serializable
    @SerialName("com.atproto.repo.applyWrites#Updateresult")
    data class Updateresult(val value: Updateresult) : OutputResultsUnion

    @Serializable
    @SerialName("com.atproto.repo.applyWrites#Deleteresult")
    data class Deleteresult(val value: Deleteresult) : OutputResultsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : OutputResultsUnion
}

object ComAtprotoRepoApplywrites {
    const val TYPE_IDENTIFIER = "com.atproto.repo.applyWrites"

    @Serializable
    data class Input(
// The handle or DID of the repo (aka, current account).        @SerialName("repo")
        val repo: ATIdentifier,// Can be set to 'false' to skip Lexicon schema validation of record data across all operations, 'true' to require it, or leave unset to validate only for known Lexicons.        @SerialName("validate")
        val validate: Boolean? = null,        @SerialName("writes")
        val writes: List<InputWritesUnion>,// If provided, the entire operation will fail if the current repo commit CID does not match this value. Used to prevent conflicting repo mutations.        @SerialName("swapCommit")
        val swapCommit: CID? = null    )

        @Serializable
    data class Output(
        @SerialName("commit")
        val commit: ComAtprotoRepoDefs.Commitmeta? = null,        @SerialName("results")
        val results: List<OutputResultsUnion>? = null    )

    sealed class Error(val name: String, val description: String?) {
        object Invalidswap: Error("InvalidSwap", "Indicates that the 'swapCommit' parameter did not match current commit.")
    }

        /**
     * Operation which creates a new record.
     */
    @Serializable
    data class Create(
        @SerialName("collection")
        val collection: NSID,/** NOTE: maxLength is redundant with record-key format. Keeping it temporarily to ensure backwards compatibility. */        @SerialName("rkey")
        val rkey: String?,        @SerialName("value")
        val value: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#create"
        }
    }

    /**
     * Operation which updates an existing record.
     */
    @Serializable
    data class Update(
        @SerialName("collection")
        val collection: NSID,        @SerialName("rkey")
        val rkey: String,        @SerialName("value")
        val value: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#update"
        }
    }

    /**
     * Operation which deletes an existing record.
     */
    @Serializable
    data class Delete(
        @SerialName("collection")
        val collection: NSID,        @SerialName("rkey")
        val rkey: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#delete"
        }
    }

    @Serializable
    data class Createresult(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("validationStatus")
        val validationStatus: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#createresult"
        }
    }

    @Serializable
    data class Updateresult(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("validationStatus")
        val validationStatus: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#updateresult"
        }
    }

    @Serializable
    data class Deleteresult(
    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#deleteresult"
        }
    }

}

/**
 * Apply a batch transaction of repository creates, updates, and deletes. Requires auth, implemented by PDS.
 *
 * Endpoint: com.atproto.repo.applyWrites
 */
suspend fun ATProtoClient.Com.Atproto.Repo.applywrites(
input: ComAtprotoRepoApplywrites.Input): ATProtoResponse<ComAtprotoRepoApplywrites.Output> {
    val endpoint = "com.atproto.repo.applyWrites"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
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
