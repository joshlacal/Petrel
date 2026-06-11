// Lexicon: 1, ID: com.atproto.label.subscribeLabels
// Subscribe to stream of labels (and negations). Public endpoint implemented by mod services. Uses same sequencing scheme as repo event stream.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoLabelSubscribeLabelsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.label.subscribeLabels"
}

@Serializable(with = ComAtprotoLabelSubscribeLabelsMessageUnionSerializer::class)
sealed interface ComAtprotoLabelSubscribeLabelsMessageUnion {
    @Serializable
    data class Labels(val value: blue.catbird.petrel.generated.ComAtprotoLabelSubscribeLabelsLabels) : ComAtprotoLabelSubscribeLabelsMessageUnion

    @Serializable
    data class Info(val value: blue.catbird.petrel.generated.ComAtprotoLabelSubscribeLabelsInfo) : ComAtprotoLabelSubscribeLabelsMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoLabelSubscribeLabelsMessageUnion
}

object ComAtprotoLabelSubscribeLabelsMessageUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoLabelSubscribeLabelsMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoLabelSubscribeLabelsMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoLabelSubscribeLabelsMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoLabelSubscribeLabelsMessageUnion.Labels -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoLabelSubscribeLabelsLabels.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.label.subscribeLabels#labels")
                })
            }
            is ComAtprotoLabelSubscribeLabelsMessageUnion.Info -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoLabelSubscribeLabelsInfo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.label.subscribeLabels#info")
                })
            }
            is ComAtprotoLabelSubscribeLabelsMessageUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoLabelSubscribeLabelsMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.label.subscribeLabels#labels" -> ComAtprotoLabelSubscribeLabelsMessageUnion.Labels(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoLabelSubscribeLabelsLabels.serializer(), element)
            )
            "com.atproto.label.subscribeLabels#info" -> ComAtprotoLabelSubscribeLabelsMessageUnion.Info(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoLabelSubscribeLabelsInfo.serializer(), element)
            )
            else -> ComAtprotoLabelSubscribeLabelsMessageUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class ComAtprotoLabelSubscribeLabelsLabels(
        @SerialName("seq")
        val seq: Int,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoLabelSubscribeLabelsLabels"
        }
    }

    @Serializable
    data class ComAtprotoLabelSubscribeLabelsInfo(
        @SerialName("name")
        val name: String,        @SerialName("message")
        val message: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoLabelSubscribeLabelsInfo"
        }
    }

@Serializable
    data class ComAtprotoLabelSubscribeLabelsParameters(
// The last known event seq number to backfill from.        @SerialName("cursor")
        val cursor: Int? = null    )

    @Serializable
    class ComAtprotoLabelSubscribeLabelsMessage

sealed class ComAtprotoLabelSubscribeLabelsError(val name: String, val description: String?) {
        object FutureCursor: ComAtprotoLabelSubscribeLabelsError("FutureCursor", "")
    }

/**
 * Synthetic variants augmenting the generated ComAtprotoLabelSubscribeLabelsMessageUnion sealed interface.
 *
 * `Error` surfaces ATProto `op == -1` server error frames; `Unexpected` wraps
 * frames whose header tag did not match any known variant (e.g. new event types
 * added server-side before client regen). Kept as extensions so the lexicon-
 * driven sealed interface stays mechanically faithful to the schema.
 */
data class ComAtprotoLabelSubscribeLabelsMessageUnionError(val name: String, val message: String?) : ComAtprotoLabelSubscribeLabelsMessageUnion
data class ComAtprotoLabelSubscribeLabelsMessageUnionUnexpected(val type: String, val payload: kotlinx.serialization.json.JsonObject) : ComAtprotoLabelSubscribeLabelsMessageUnion

/**
 * Subscribe to stream of labels (and negations). Public endpoint implemented by mod services. Uses same sequencing scheme as repo event stream.
 *
 * Endpoint: com.atproto.label.subscribeLabels
 *
 * The returned [kotlinx.coroutines.flow.Flow] completes (or throws) when the
 * underlying WebSocket disconnects. Reconnect / cursor-resume is the caller's
 * responsibility — wrap in `retryWhen { ... }` with backoff as needed.
 */
fun ATProtoClient.Com.Atproto.Label.subscribeLabels(
parameters: ComAtprotoLabelSubscribeLabelsParameters? = null,
hostOverride: String? = null,
    websocketClient: io.ktor.client.HttpClient? = null,
): kotlinx.coroutines.flow.Flow<ComAtprotoLabelSubscribeLabelsMessageUnion> = kotlinx.coroutines.flow.flow {
    val endpoint = "com.atproto.label.subscribeLabels"
    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?collections=a&collections=b`).
    val queryItems = parameters?.toQueryItems().orEmpty()

    client.openSubscription(endpoint, queryItems, hostOverride, websocketClient) { frame ->
        val decoded: ComAtprotoLabelSubscribeLabelsMessageUnion = when (frame) {
            is blue.catbird.petrel.runtime.subscription.CborFrame.Error ->
                ComAtprotoLabelSubscribeLabelsMessageUnionError(frame.name, frame.message)
            is blue.catbird.petrel.runtime.subscription.CborFrame.Message -> {
                val json = kotlinx.serialization.json.Json {
                    ignoreUnknownKeys = true
                    isLenient = true
                }
                try {
                    when (frame.header.t) {
                        "#labels" -> ComAtprotoLabelSubscribeLabelsMessageUnion.Labels(
                            json.decodeFromJsonElement(
                                blue.catbird.petrel.generated.ComAtprotoLabelSubscribeLabelsLabels.serializer(),
                                frame.payload
                            )
                        )
                        "#info" -> ComAtprotoLabelSubscribeLabelsMessageUnion.Info(
                            json.decodeFromJsonElement(
                                blue.catbird.petrel.generated.ComAtprotoLabelSubscribeLabelsInfo.serializer(),
                                frame.payload
                            )
                        )
                        else -> ComAtprotoLabelSubscribeLabelsMessageUnionUnexpected(frame.header.t, frame.payload)
                    }
                } catch (e: Throwable) {
                    ComAtprotoLabelSubscribeLabelsMessageUnionUnexpected(frame.header.t, frame.payload)
                }
            }
        }
        emit(decoded)
    }
}
