// Lexicon: 1, ID: com.atproto.sync.subscribeRepos
// Repository event stream, aka Firehose endpoint. Outputs repo commits with diff data, and identity update events, for all repositories on the current server. See the atproto specifications for details around stream sequencing, repo versioning, CAR diff format, and more. Public and does not require auth; implemented by PDS and Relay.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncSubscribeReposDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.subscribeRepos"
}

    /**
     * Represents an update of repository state. Note that empty commits are allowed, which include no repo data changes, but an update to rev and signature.
     */
    @Serializable
    data class ComAtprotoSyncSubscribeReposCommit(
/** The stream sequence number of this message. */        @SerialName("seq")
        val seq: Int,/** DEPRECATED -- unused */        @SerialName("rebase")
        val rebase: Boolean,/** DEPRECATED -- replaced by #sync event and data limits. Indicates that this commit contained too many ops, or data size was too large. Consumers will need to make a separate request to get missing data. */        @SerialName("tooBig")
        val tooBig: Boolean,/** The repo this event comes from. Note that all other message types name this field 'did'. */        @SerialName("repo")
        val repo: DID,/** Repo commit object CID. */        @SerialName("commit")
        val commit: JsonElement,/** The rev of the emitted commit. Note that this information is also in the commit object included in blocks, unless this is a tooBig event. */        @SerialName("rev")
        val rev: String,/** The rev of the last emitted commit from this repo (if any). */        @SerialName("since")
        val since: String,/** CAR file containing relevant blocks, as a diff since the previous repo state. The commit must be included as a block, and the commit block CID must be the first entry in the CAR header 'roots' list. */        @SerialName("blocks")
        val blocks: ByteArray,        @SerialName("ops")
        val ops: List<ComAtprotoSyncSubscribeReposRepoOp>,        @SerialName("blobs")
        val blobs: List<JsonElement>,/** The root CID of the MST tree for the previous commit from this repo (indicated by the 'since' revision field in this message). Corresponds to the 'data' field in the repo commit object. NOTE: this field is effectively required for the 'inductive' version of firehose. */        @SerialName("prevData")
        val prevData: JsonElement?,/** Timestamp of when this message was originally broadcast. */        @SerialName("time")
        val time: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSyncSubscribeReposCommit"
        }
    }

    /**
     * Updates the repo to a new state, without necessarily including that state on the firehose. Used to recover from broken commit streams, data loss incidents, or in situations where upstream host does not know recent state of the repository.
     */
    @Serializable
    data class ComAtprotoSyncSubscribeReposSync(
/** The stream sequence number of this message. */        @SerialName("seq")
        val seq: Int,/** The account this repo event corresponds to. Must match that in the commit object. */        @SerialName("did")
        val did: DID,/** CAR file containing the commit, as a block. The CAR header must include the commit block CID as the first 'root'. */        @SerialName("blocks")
        val blocks: ByteArray,/** The rev of the commit. This value must match that in the commit object. */        @SerialName("rev")
        val rev: String,/** Timestamp of when this message was originally broadcast. */        @SerialName("time")
        val time: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSyncSubscribeReposSync"
        }
    }

    /**
     * Represents a change to an account's identity. Could be an updated handle, signing key, or pds hosting endpoint. Serves as a prod to all downstream services to refresh their identity cache.
     */
    @Serializable
    data class ComAtprotoSyncSubscribeReposIdentity(
        @SerialName("seq")
        val seq: Int,        @SerialName("did")
        val did: DID,        @SerialName("time")
        val time: ATProtocolDate,/** The current handle for the account, or 'handle.invalid' if validation fails. This field is optional, might have been validated or passed-through from an upstream source. Semantics and behaviors for PDS vs Relay may evolve in the future; see atproto specs for more details. */        @SerialName("handle")
        val handle: Handle?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSyncSubscribeReposIdentity"
        }
    }

    /**
     * Represents a change to an account's status on a host (eg, PDS or Relay). The semantics of this event are that the status is at the host which emitted the event, not necessarily that at the currently active PDS. Eg, a Relay takedown would emit a takedown with active=false, even if the PDS is still active.
     */
    @Serializable
    data class ComAtprotoSyncSubscribeReposAccount(
        @SerialName("seq")
        val seq: Int,        @SerialName("did")
        val did: DID,        @SerialName("time")
        val time: ATProtocolDate,/** Indicates that the account has a repository which can be fetched from the host that emitted this event. */        @SerialName("active")
        val active: Boolean,/** If active=false, this optional field indicates a reason for why the account is not active. */        @SerialName("status")
        val status: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSyncSubscribeReposAccount"
        }
    }

    @Serializable
    data class ComAtprotoSyncSubscribeReposInfo(
        @SerialName("name")
        val name: String,        @SerialName("message")
        val message: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSyncSubscribeReposInfo"
        }
    }

    /**
     * A repo operation, ie a mutation of a single record.
     */
    @Serializable
    data class ComAtprotoSyncSubscribeReposRepoOp(
        @SerialName("action")
        val action: String,        @SerialName("path")
        val path: String,/** For creates and updates, the new record CID. For deletions, null. */        @SerialName("cid")
        val cid: JsonElement,/** For updates and deletes, the previous record CID (required for inductive firehose). For creations, field should not be defined. */        @SerialName("prev")
        val prev: JsonElement?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSyncSubscribeReposRepoOp"
        }
    }

@Serializable
    data class ComAtprotoSyncSubscribeReposParameters(
// The last known event seq number to backfill from.        @SerialName("cursor")
        val cursor: Int? = null    )

    @Serializable
    class ComAtprotoSyncSubscribeReposMessage

sealed class ComAtprotoSyncSubscribeReposError(val name: String, val description: String?) {
        object FutureCursor: ComAtprotoSyncSubscribeReposError("FutureCursor", "")
        object ConsumerTooSlow: ComAtprotoSyncSubscribeReposError("ConsumerTooSlow", "If the consumer of the stream can not keep up with events, and a backlog gets too large, the server will drop the connection.")
    }

/**
 * Repository event stream, aka Firehose endpoint. Outputs repo commits with diff data, and identity update events, for all repositories on the current server. See the atproto specifications for details around stream sequencing, repo versioning, CAR diff format, and more. Public and does not require auth; implemented by PDS and Relay.
 *
 * Endpoint: com.atproto.sync.subscribeRepos
 */
fun ATProtoClient.Com.Atproto.Sync.subscribeRepos(
parameters: ComAtprotoSyncSubscribeReposParameters): Flow<ComAtprotoSyncSubscribeReposMessage> = flow {
    val endpoint = "com.atproto.sync.subscribeRepos"

    val queryParams = parameters.toQueryParams()

    // TODO: Implement WebSocket connection using a WebSocket library (e.g., Ktor WebSockets)
    // The implementation should:
    // 1. Establish WebSocket connection to endpoint with queryParams
    // 2. Listen for incoming messages
    // 3. Deserialize each message as ComAtprotoSyncSubscribeReposMessage
    // 4. Emit each message to the Flow
    // Example skeleton:
    // webSocketClient.connect(endpoint, queryParams) { message ->
    //     val decoded = Json.decodeFromString<ComAtprotoSyncSubscribeReposMessage>(message)
    //     emit(decoded)
    // }
    throw NotImplementedError("WebSocket subscription support requires a WebSocket client implementation")
}
