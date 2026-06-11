// Lexicon: 1, ID: com.atproto.sync.subscribeRepos
// Repository event stream, aka Firehose endpoint. Outputs repo commits with diff data, and identity update events, for all repositories on the current server. See the atproto specifications for details around stream sequencing, repo versioning, CAR diff format, and more. Public and does not require auth; implemented by PDS and Relay.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSyncSubscribeReposDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.subscribeRepos"
}

@Serializable(with = ComAtprotoSyncSubscribeReposMessageUnionSerializer::class)
sealed interface ComAtprotoSyncSubscribeReposMessageUnion {
    @Serializable
    data class Commit(val value: blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposCommit) : ComAtprotoSyncSubscribeReposMessageUnion

    @Serializable
    data class Sync(val value: blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposSync) : ComAtprotoSyncSubscribeReposMessageUnion

    @Serializable
    data class Identity(val value: blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposIdentity) : ComAtprotoSyncSubscribeReposMessageUnion

    @Serializable
    data class Account(val value: blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposAccount) : ComAtprotoSyncSubscribeReposMessageUnion

    @Serializable
    data class Info(val value: blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposInfo) : ComAtprotoSyncSubscribeReposMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoSyncSubscribeReposMessageUnion
}

object ComAtprotoSyncSubscribeReposMessageUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoSyncSubscribeReposMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoSyncSubscribeReposMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoSyncSubscribeReposMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoSyncSubscribeReposMessageUnion.Commit -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposCommit.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.sync.subscribeRepos#commit")
                })
            }
            is ComAtprotoSyncSubscribeReposMessageUnion.Sync -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposSync.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.sync.subscribeRepos#sync")
                })
            }
            is ComAtprotoSyncSubscribeReposMessageUnion.Identity -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposIdentity.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.sync.subscribeRepos#identity")
                })
            }
            is ComAtprotoSyncSubscribeReposMessageUnion.Account -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposAccount.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.sync.subscribeRepos#account")
                })
            }
            is ComAtprotoSyncSubscribeReposMessageUnion.Info -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposInfo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.sync.subscribeRepos#info")
                })
            }
            is ComAtprotoSyncSubscribeReposMessageUnion.Unexpected -> value.value
            // Synthetic variants (e.g. <Union>Error / <Union>Unexpected added by
            // subscription codegen) are runtime-only sentinels; JSON round-trip
            // serialises them as an empty object tagged with the variant class
            // name. Consumers should filter these before JSON serialisation.
            else -> kotlinx.serialization.json.buildJsonObject {
                put("\$type", kotlinx.serialization.json.JsonPrimitive(value::class.simpleName ?: "Unknown"))
            }
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoSyncSubscribeReposMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.sync.subscribeRepos#commit" -> ComAtprotoSyncSubscribeReposMessageUnion.Commit(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposCommit.serializer(), element)
            )
            "com.atproto.sync.subscribeRepos#sync" -> ComAtprotoSyncSubscribeReposMessageUnion.Sync(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposSync.serializer(), element)
            )
            "com.atproto.sync.subscribeRepos#identity" -> ComAtprotoSyncSubscribeReposMessageUnion.Identity(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposIdentity.serializer(), element)
            )
            "com.atproto.sync.subscribeRepos#account" -> ComAtprotoSyncSubscribeReposMessageUnion.Account(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposAccount.serializer(), element)
            )
            "com.atproto.sync.subscribeRepos#info" -> ComAtprotoSyncSubscribeReposMessageUnion.Info(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposInfo.serializer(), element)
            )
            else -> ComAtprotoSyncSubscribeReposMessageUnion.Unexpected(element)
        }
    }
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
        val blocks: Bytes,        @SerialName("ops")
        val ops: List<ComAtprotoSyncSubscribeReposRepoOp>,        @SerialName("blobs")
        val blobs: List<JsonElement>,/** The root CID of the MST tree for the previous commit from this repo (indicated by the 'since' revision field in this message). Corresponds to the 'data' field in the repo commit object. NOTE: this field is effectively required for the 'inductive' version of firehose. */        @SerialName("prevData")
        val prevData: JsonElement? = null,/** Timestamp of when this message was originally broadcast. */        @SerialName("time")
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
        val blocks: Bytes,/** The rev of the commit. This value must match that in the commit object. */        @SerialName("rev")
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
        val handle: Handle? = null    ) {
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
        val status: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSyncSubscribeReposAccount"
        }
    }

    @Serializable
    data class ComAtprotoSyncSubscribeReposInfo(
        @SerialName("name")
        val name: String,        @SerialName("message")
        val message: String? = null    ) {
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
        val prev: JsonElement? = null    ) {
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
 * Synthetic variants augmenting the generated ComAtprotoSyncSubscribeReposMessageUnion sealed interface.
 *
 * `Error` surfaces ATProto `op == -1` server error frames; `Unexpected` wraps
 * frames whose header tag did not match any known variant (e.g. new event types
 * added server-side before client regen). Kept as extensions so the lexicon-
 * driven sealed interface stays mechanically faithful to the schema.
 */
data class ComAtprotoSyncSubscribeReposMessageUnionError(val name: String, val message: String?) : ComAtprotoSyncSubscribeReposMessageUnion
data class ComAtprotoSyncSubscribeReposMessageUnionUnexpected(val type: String, val payload: kotlinx.serialization.json.JsonObject) : ComAtprotoSyncSubscribeReposMessageUnion

/**
 * Repository event stream, aka Firehose endpoint. Outputs repo commits with diff data, and identity update events, for all repositories on the current server. See the atproto specifications for details around stream sequencing, repo versioning, CAR diff format, and more. Public and does not require auth; implemented by PDS and Relay.
 *
 * Endpoint: com.atproto.sync.subscribeRepos
 *
 * The returned [kotlinx.coroutines.flow.Flow] completes (or throws) when the
 * underlying WebSocket disconnects. Reconnect / cursor-resume is the caller's
 * responsibility — wrap in `retryWhen { ... }` with backoff as needed.
 */
fun ATProtoClient.Com.Atproto.Sync.subscribeRepos(
parameters: ComAtprotoSyncSubscribeReposParameters? = null,
hostOverride: String? = null,
    websocketClient: io.ktor.client.HttpClient? = null,
): kotlinx.coroutines.flow.Flow<ComAtprotoSyncSubscribeReposMessageUnion> = kotlinx.coroutines.flow.flow {
    val endpoint = "com.atproto.sync.subscribeRepos"
    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?collections=a&collections=b`).
    val queryItems = parameters?.toQueryItems().orEmpty()

    client.openSubscription(endpoint, queryItems, hostOverride, websocketClient) { frame ->
        val decoded: ComAtprotoSyncSubscribeReposMessageUnion = when (frame) {
            is blue.catbird.petrel.runtime.subscription.CborFrame.Error ->
                ComAtprotoSyncSubscribeReposMessageUnionError(frame.name, frame.message)
            is blue.catbird.petrel.runtime.subscription.CborFrame.Message -> {
                val json = kotlinx.serialization.json.Json {
                    ignoreUnknownKeys = true
                    isLenient = true
                }
                try {
                    when (frame.header.t) {
                        "#commit" -> ComAtprotoSyncSubscribeReposMessageUnion.Commit(
                            json.decodeFromJsonElement(
                                blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposCommit.serializer(),
                                frame.payload
                            )
                        )
                        "#sync" -> ComAtprotoSyncSubscribeReposMessageUnion.Sync(
                            json.decodeFromJsonElement(
                                blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposSync.serializer(),
                                frame.payload
                            )
                        )
                        "#identity" -> ComAtprotoSyncSubscribeReposMessageUnion.Identity(
                            json.decodeFromJsonElement(
                                blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposIdentity.serializer(),
                                frame.payload
                            )
                        )
                        "#account" -> ComAtprotoSyncSubscribeReposMessageUnion.Account(
                            json.decodeFromJsonElement(
                                blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposAccount.serializer(),
                                frame.payload
                            )
                        )
                        "#info" -> ComAtprotoSyncSubscribeReposMessageUnion.Info(
                            json.decodeFromJsonElement(
                                blue.catbird.petrel.generated.ComAtprotoSyncSubscribeReposInfo.serializer(),
                                frame.payload
                            )
                        )
                        else -> ComAtprotoSyncSubscribeReposMessageUnionUnexpected(frame.header.t, frame.payload)
                    }
                } catch (e: Throwable) {
                    ComAtprotoSyncSubscribeReposMessageUnionUnexpected(frame.header.t, frame.payload)
                }
            }
        }
        emit(decoded)
    }
}
