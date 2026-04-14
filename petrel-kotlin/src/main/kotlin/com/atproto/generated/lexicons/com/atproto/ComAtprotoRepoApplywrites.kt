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

@Serializable(with = ComAtprotoRepoApplyWritesInputWritesUnionSerializer::class)
sealed interface ComAtprotoRepoApplyWritesInputWritesUnion {
    @Serializable
    data class Create(val value: com.atproto.generated.ComAtprotoRepoApplyWritesCreate) : ComAtprotoRepoApplyWritesInputWritesUnion

    @Serializable
    data class Update(val value: com.atproto.generated.ComAtprotoRepoApplyWritesUpdate) : ComAtprotoRepoApplyWritesInputWritesUnion

    @Serializable
    data class Delete(val value: com.atproto.generated.ComAtprotoRepoApplyWritesDelete) : ComAtprotoRepoApplyWritesInputWritesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoRepoApplyWritesInputWritesUnion
}

object ComAtprotoRepoApplyWritesInputWritesUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoRepoApplyWritesInputWritesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoRepoApplyWritesInputWritesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoRepoApplyWritesInputWritesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoRepoApplyWritesInputWritesUnion.Create -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesCreate.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.applyWrites#create")
                })
            }
            is ComAtprotoRepoApplyWritesInputWritesUnion.Update -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesUpdate.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.applyWrites#update")
                })
            }
            is ComAtprotoRepoApplyWritesInputWritesUnion.Delete -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesDelete.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.applyWrites#delete")
                })
            }
            is ComAtprotoRepoApplyWritesInputWritesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoRepoApplyWritesInputWritesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.repo.applyWrites#create" -> ComAtprotoRepoApplyWritesInputWritesUnion.Create(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesCreate.serializer(), element)
            )
            "com.atproto.repo.applyWrites#update" -> ComAtprotoRepoApplyWritesInputWritesUnion.Update(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesUpdate.serializer(), element)
            )
            "com.atproto.repo.applyWrites#delete" -> ComAtprotoRepoApplyWritesInputWritesUnion.Delete(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesDelete.serializer(), element)
            )
            else -> ComAtprotoRepoApplyWritesInputWritesUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ComAtprotoRepoApplyWritesOutputResultsUnionSerializer::class)
sealed interface ComAtprotoRepoApplyWritesOutputResultsUnion {
    @Serializable
    data class CreateResult(val value: com.atproto.generated.ComAtprotoRepoApplyWritesCreateResult) : ComAtprotoRepoApplyWritesOutputResultsUnion

    @Serializable
    data class UpdateResult(val value: com.atproto.generated.ComAtprotoRepoApplyWritesUpdateResult) : ComAtprotoRepoApplyWritesOutputResultsUnion

    @Serializable
    data class DeleteResult(val value: com.atproto.generated.ComAtprotoRepoApplyWritesDeleteResult) : ComAtprotoRepoApplyWritesOutputResultsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoRepoApplyWritesOutputResultsUnion
}

object ComAtprotoRepoApplyWritesOutputResultsUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoRepoApplyWritesOutputResultsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoRepoApplyWritesOutputResultsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoRepoApplyWritesOutputResultsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoRepoApplyWritesOutputResultsUnion.CreateResult -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesCreateResult.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.applyWrites#createResult")
                })
            }
            is ComAtprotoRepoApplyWritesOutputResultsUnion.UpdateResult -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesUpdateResult.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.applyWrites#updateResult")
                })
            }
            is ComAtprotoRepoApplyWritesOutputResultsUnion.DeleteResult -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesDeleteResult.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.applyWrites#deleteResult")
                })
            }
            is ComAtprotoRepoApplyWritesOutputResultsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoRepoApplyWritesOutputResultsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.repo.applyWrites#createResult" -> ComAtprotoRepoApplyWritesOutputResultsUnion.CreateResult(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesCreateResult.serializer(), element)
            )
            "com.atproto.repo.applyWrites#updateResult" -> ComAtprotoRepoApplyWritesOutputResultsUnion.UpdateResult(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesUpdateResult.serializer(), element)
            )
            "com.atproto.repo.applyWrites#deleteResult" -> ComAtprotoRepoApplyWritesOutputResultsUnion.DeleteResult(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoRepoApplyWritesDeleteResult.serializer(), element)
            )
            else -> ComAtprotoRepoApplyWritesOutputResultsUnion.Unexpected(element)
        }
    }
}

    /**
     * Operation which creates a new record.
     */
    @Serializable
    data class ComAtprotoRepoApplyWritesCreate(
        @SerialName("collection")
        val collection: NSID,/** NOTE: maxLength is redundant with record-key format. Keeping it temporarily to ensure backwards compatibility. */        @SerialName("rkey")
        val rkey: String? = null,        @SerialName("value")
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
        val validationStatus: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoRepoApplyWritesCreateResult"
        }
    }

    @Serializable
    data class ComAtprotoRepoApplyWritesUpdateResult(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("validationStatus")
        val validationStatus: String? = null    ) {
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
