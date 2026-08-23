// Lexicon: 1, ID: com.atproto.space.applyWrites
// Apply a batch transaction of creates, updates, and deletes in a permissioned space. Requires auth, implemented by PDS.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSpaceApplyWritesDefs {
    const val TYPE_IDENTIFIER = "com.atproto.space.applyWrites"
}

@Serializable(with = ComAtprotoSpaceApplyWritesInputWritesUnionSerializer::class)
sealed interface ComAtprotoSpaceApplyWritesInputWritesUnion {
    @Serializable
    data class Create(val value: blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesCreate) : ComAtprotoSpaceApplyWritesInputWritesUnion

    @Serializable
    data class Update(val value: blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesUpdate) : ComAtprotoSpaceApplyWritesInputWritesUnion

    @Serializable
    data class Delete(val value: blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesDelete) : ComAtprotoSpaceApplyWritesInputWritesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoSpaceApplyWritesInputWritesUnion
}

object ComAtprotoSpaceApplyWritesInputWritesUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoSpaceApplyWritesInputWritesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoSpaceApplyWritesInputWritesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoSpaceApplyWritesInputWritesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoSpaceApplyWritesInputWritesUnion.Create -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesCreate.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.space.applyWrites#create")
                })
            }
            is ComAtprotoSpaceApplyWritesInputWritesUnion.Update -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesUpdate.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.space.applyWrites#update")
                })
            }
            is ComAtprotoSpaceApplyWritesInputWritesUnion.Delete -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesDelete.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.space.applyWrites#delete")
                })
            }
            is ComAtprotoSpaceApplyWritesInputWritesUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoSpaceApplyWritesInputWritesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.space.applyWrites#create" -> ComAtprotoSpaceApplyWritesInputWritesUnion.Create(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesCreate.serializer(), element)
            )
            "com.atproto.space.applyWrites#update" -> ComAtprotoSpaceApplyWritesInputWritesUnion.Update(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesUpdate.serializer(), element)
            )
            "com.atproto.space.applyWrites#delete" -> ComAtprotoSpaceApplyWritesInputWritesUnion.Delete(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesDelete.serializer(), element)
            )
            else -> ComAtprotoSpaceApplyWritesInputWritesUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ComAtprotoSpaceApplyWritesOutputResultsUnionSerializer::class)
sealed interface ComAtprotoSpaceApplyWritesOutputResultsUnion {
    @Serializable
    data class CreateResult(val value: blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesCreateResult) : ComAtprotoSpaceApplyWritesOutputResultsUnion

    @Serializable
    data class UpdateResult(val value: blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesUpdateResult) : ComAtprotoSpaceApplyWritesOutputResultsUnion

    @Serializable
    data class DeleteResult(val value: blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesDeleteResult) : ComAtprotoSpaceApplyWritesOutputResultsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoSpaceApplyWritesOutputResultsUnion
}

object ComAtprotoSpaceApplyWritesOutputResultsUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoSpaceApplyWritesOutputResultsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoSpaceApplyWritesOutputResultsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoSpaceApplyWritesOutputResultsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoSpaceApplyWritesOutputResultsUnion.CreateResult -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesCreateResult.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.space.applyWrites#createResult")
                })
            }
            is ComAtprotoSpaceApplyWritesOutputResultsUnion.UpdateResult -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesUpdateResult.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.space.applyWrites#updateResult")
                })
            }
            is ComAtprotoSpaceApplyWritesOutputResultsUnion.DeleteResult -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesDeleteResult.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.space.applyWrites#deleteResult")
                })
            }
            is ComAtprotoSpaceApplyWritesOutputResultsUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoSpaceApplyWritesOutputResultsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.space.applyWrites#createResult" -> ComAtprotoSpaceApplyWritesOutputResultsUnion.CreateResult(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesCreateResult.serializer(), element)
            )
            "com.atproto.space.applyWrites#updateResult" -> ComAtprotoSpaceApplyWritesOutputResultsUnion.UpdateResult(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesUpdateResult.serializer(), element)
            )
            "com.atproto.space.applyWrites#deleteResult" -> ComAtprotoSpaceApplyWritesOutputResultsUnion.DeleteResult(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSpaceApplyWritesDeleteResult.serializer(), element)
            )
            else -> ComAtprotoSpaceApplyWritesOutputResultsUnion.Unexpected(element)
        }
    }
}

    /**
     * Operation which creates a new record.
     */
    @Serializable
    data class ComAtprotoSpaceApplyWritesCreate(
        @SerialName("collection")
        val collection: NSID,        @SerialName("rkey")
        val rkey: String? = null,        @SerialName("value")
        val value: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSpaceApplyWritesCreate"
        }
    }

    /**
     * Operation which updates an existing record.
     */
    @Serializable
    data class ComAtprotoSpaceApplyWritesUpdate(
        @SerialName("collection")
        val collection: NSID,        @SerialName("rkey")
        val rkey: String,        @SerialName("value")
        val value: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSpaceApplyWritesUpdate"
        }
    }

    /**
     * Operation which deletes an existing record.
     */
    @Serializable
    data class ComAtprotoSpaceApplyWritesDelete(
        @SerialName("collection")
        val collection: NSID,        @SerialName("rkey")
        val rkey: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSpaceApplyWritesDelete"
        }
    }

    @Serializable
    data class ComAtprotoSpaceApplyWritesCreateResult(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("validationStatus")
        val validationStatus: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSpaceApplyWritesCreateResult"
        }
    }

    @Serializable
    data class ComAtprotoSpaceApplyWritesUpdateResult(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("validationStatus")
        val validationStatus: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSpaceApplyWritesUpdateResult"
        }
    }

    @Serializable
    class ComAtprotoSpaceApplyWritesDeleteResult {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSpaceApplyWritesDeleteResult"
        }
    }

@Serializable
    data class ComAtprotoSpaceApplyWritesInput(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef,// The DID of the repo to write to (the authenticated member).        @SerialName("repo")
        val repo: DID,// Can be set to 'false' to skip Lexicon schema validation of record data across all operations, 'true' to require it, or leave unset to validate only for known Lexicons.        @SerialName("validate")
        val validate: Boolean? = null,        @SerialName("writes")
        val writes: List<ComAtprotoSpaceApplyWritesInputWritesUnion>    )

    @Serializable
    data class ComAtprotoSpaceApplyWritesOutput(
        @SerialName("results")
        val results: List<ComAtprotoSpaceApplyWritesOutputResultsUnion>? = null    )

sealed class ComAtprotoSpaceApplyWritesError(val name: String, val description: String?) {
        object SpaceNotFound: ComAtprotoSpaceApplyWritesError("SpaceNotFound", "")
        object RecordNotFound: ComAtprotoSpaceApplyWritesError("RecordNotFound", "An update or delete targeted a record that does not exist.")
        object RecordAlreadyExists: ComAtprotoSpaceApplyWritesError("RecordAlreadyExists", "A create targeted a collection and rkey that already holds a record.")
    }

/**
 * Apply a batch transaction of creates, updates, and deletes in a permissioned space. Requires auth, implemented by PDS.
 *
 * Endpoint: com.atproto.space.applyWrites
 */
suspend fun ATProtoClient.Com.Atproto.Space.applyWrites(
input: ComAtprotoSpaceApplyWritesInput): ATProtoResponse<ComAtprotoSpaceApplyWritesOutput> {
    val endpoint = "com.atproto.space.applyWrites"

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
