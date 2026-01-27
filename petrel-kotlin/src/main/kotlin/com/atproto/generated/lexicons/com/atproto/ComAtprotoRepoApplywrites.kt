// Lexicon: 1, ID: com.atproto.repo.applyWrites
// Apply a batch transaction of repository creates, updates, and deletes. Requires auth, implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoRepoApplyWritesDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.applyWrites"
}

@Serializable
sealed interface ComAtprotoRepoApplyWritesInputWritesUnion {
    @Serializable
    @SerialName("com.atproto.repo.applyWrites#ComAtprotoRepoApplyWritesCreate")
    data class ComAtprotoRepoApplyWritesCreate(val value: ComAtprotoRepoApplyWritesCreate) : ComAtprotoRepoApplyWritesInputWritesUnion

    @Serializable
    @SerialName("com.atproto.repo.applyWrites#ComAtprotoRepoApplyWritesUpdate")
    data class ComAtprotoRepoApplyWritesUpdate(val value: ComAtprotoRepoApplyWritesUpdate) : ComAtprotoRepoApplyWritesInputWritesUnion

    @Serializable
    @SerialName("com.atproto.repo.applyWrites#ComAtprotoRepoApplyWritesDelete")
    data class ComAtprotoRepoApplyWritesDelete(val value: ComAtprotoRepoApplyWritesDelete) : ComAtprotoRepoApplyWritesInputWritesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ComAtprotoRepoApplyWritesInputWritesUnion
}

@Serializable
sealed interface ComAtprotoRepoApplyWritesOutputResultsUnion {
    @Serializable
    @SerialName("com.atproto.repo.applyWrites#ComAtprotoRepoApplyWritesCreateResult")
    data class ComAtprotoRepoApplyWritesCreateResult(val value: ComAtprotoRepoApplyWritesCreateResult) : ComAtprotoRepoApplyWritesOutputResultsUnion

    @Serializable
    @SerialName("com.atproto.repo.applyWrites#ComAtprotoRepoApplyWritesUpdateResult")
    data class ComAtprotoRepoApplyWritesUpdateResult(val value: ComAtprotoRepoApplyWritesUpdateResult) : ComAtprotoRepoApplyWritesOutputResultsUnion

    @Serializable
    @SerialName("com.atproto.repo.applyWrites#ComAtprotoRepoApplyWritesDeleteResult")
    data class ComAtprotoRepoApplyWritesDeleteResult(val value: ComAtprotoRepoApplyWritesDeleteResult) : ComAtprotoRepoApplyWritesOutputResultsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ComAtprotoRepoApplyWritesOutputResultsUnion
}

    /**
     * Operation which creates a new record.
     */
    @Serializable
    data class ComAtprotoRepoApplyWritesCreate(
        @SerialName("collection")
        val collection: NSID,/** NOTE: maxLength is redundant with record-key format. Keeping it temporarily to ensure backwards compatibility. */        @SerialName("rkey")
        val rkey: String?,        @SerialName("value")
        val value: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoRepoApplyWritesCreate"
        }
    }

    /**
     * Operation which updates an existing record.
     */
    @Serializable
    data class ComAtprotoRepoApplyWritesUpdate(
        @SerialName("collection")
        val collection: NSID,        @SerialName("rkey")
        val rkey: String,        @SerialName("value")
        val value: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoRepoApplyWritesUpdate"
        }
    }

    /**
     * Operation which deletes an existing record.
     */
    @Serializable
    data class ComAtprotoRepoApplyWritesDelete(
        @SerialName("collection")
        val collection: NSID,        @SerialName("rkey")
        val rkey: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoRepoApplyWritesDelete"
        }
    }

    @Serializable
    data class ComAtprotoRepoApplyWritesCreateResult(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("validationStatus")
        val validationStatus: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoRepoApplyWritesCreateResult"
        }
    }

    @Serializable
    data class ComAtprotoRepoApplyWritesUpdateResult(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("validationStatus")
        val validationStatus: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoRepoApplyWritesUpdateResult"
        }
    }

    @Serializable
    class ComAtprotoRepoApplyWritesDeleteResult {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoRepoApplyWritesDeleteResult"
        }
    }

@Serializable
    data class ComAtprotoRepoApplyWritesInput(
// The handle or DID of the repo (aka, current account).        @SerialName("repo")
        val repo: ATIdentifier,// Can be set to 'false' to skip Lexicon schema validation of record data across all operations, 'true' to require it, or leave unset to validate only for known Lexicons.        @SerialName("validate")
        val validate: Boolean? = null,        @SerialName("writes")
        val writes: List<ComAtprotoRepoApplyWritesInputWritesUnion>,// If provided, the entire operation will fail if the current repo commit CID does not match this value. Used to prevent conflicting repo mutations.        @SerialName("swapCommit")
        val swapCommit: CID? = null    )

    @Serializable
    data class ComAtprotoRepoApplyWritesOutput(
        @SerialName("commit")
        val commit: ComAtprotoRepoDefsCommitMeta? = null,        @SerialName("results")
        val results: List<ComAtprotoRepoApplyWritesOutputResultsUnion>? = null    )

sealed class ComAtprotoRepoApplyWritesError(val name: String, val description: String?) {
        object InvalidSwap: ComAtprotoRepoApplyWritesError("InvalidSwap", "Indicates that the 'swapCommit' parameter did not match current commit.")
    }

/**
 * Apply a batch transaction of repository creates, updates, and deletes. Requires auth, implemented by PDS.
 *
 * Endpoint: com.atproto.repo.applyWrites
 */
suspend fun ATProtoClient.Com.Atproto.Repo.applyWrites(
input: ComAtprotoRepoApplyWritesInput): ATProtoResponse<ComAtprotoRepoApplyWritesOutput> {
    val endpoint = "com.atproto.repo.applyWrites"

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
