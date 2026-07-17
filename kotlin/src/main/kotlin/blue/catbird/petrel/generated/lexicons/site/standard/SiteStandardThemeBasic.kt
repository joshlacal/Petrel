// Lexicon: 1, ID: site.standard.theme.basic
// A simplified theme definition for publications, providing basic color customization for content display across different platforms and applications.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object SiteStandardThemeBasicDefs {
    const val TYPE_IDENTIFIER = "site.standard.theme.basic"
}

@Serializable(with = SiteStandardThemeBasicAccentUnionSerializer::class)
sealed interface SiteStandardThemeBasicAccentUnion {
    @Serializable
    data class Rgb(val value: blue.catbird.petrel.generated.SiteStandardThemeColorRgb) : SiteStandardThemeBasicAccentUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : SiteStandardThemeBasicAccentUnion
}

object SiteStandardThemeBasicAccentUnionSerializer : kotlinx.serialization.KSerializer<SiteStandardThemeBasicAccentUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("SiteStandardThemeBasicAccentUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: SiteStandardThemeBasicAccentUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is SiteStandardThemeBasicAccentUnion.Rgb -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.SiteStandardThemeColorRgb.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("site.standard.theme.color#rgb")
                })
            }
            is SiteStandardThemeBasicAccentUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): SiteStandardThemeBasicAccentUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "site.standard.theme.color#rgb" -> SiteStandardThemeBasicAccentUnion.Rgb(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.SiteStandardThemeColorRgb.serializer(), element)
            )
            else -> SiteStandardThemeBasicAccentUnion.Unexpected(element)
        }
    }
}

@Serializable(with = SiteStandardThemeBasicAccentForegroundUnionSerializer::class)
sealed interface SiteStandardThemeBasicAccentForegroundUnion {
    @Serializable
    data class Rgb(val value: blue.catbird.petrel.generated.SiteStandardThemeColorRgb) : SiteStandardThemeBasicAccentForegroundUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : SiteStandardThemeBasicAccentForegroundUnion
}

object SiteStandardThemeBasicAccentForegroundUnionSerializer : kotlinx.serialization.KSerializer<SiteStandardThemeBasicAccentForegroundUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("SiteStandardThemeBasicAccentForegroundUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: SiteStandardThemeBasicAccentForegroundUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is SiteStandardThemeBasicAccentForegroundUnion.Rgb -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.SiteStandardThemeColorRgb.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("site.standard.theme.color#rgb")
                })
            }
            is SiteStandardThemeBasicAccentForegroundUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): SiteStandardThemeBasicAccentForegroundUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "site.standard.theme.color#rgb" -> SiteStandardThemeBasicAccentForegroundUnion.Rgb(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.SiteStandardThemeColorRgb.serializer(), element)
            )
            else -> SiteStandardThemeBasicAccentForegroundUnion.Unexpected(element)
        }
    }
}

@Serializable(with = SiteStandardThemeBasicBackgroundUnionSerializer::class)
sealed interface SiteStandardThemeBasicBackgroundUnion {
    @Serializable
    data class Rgb(val value: blue.catbird.petrel.generated.SiteStandardThemeColorRgb) : SiteStandardThemeBasicBackgroundUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : SiteStandardThemeBasicBackgroundUnion
}

object SiteStandardThemeBasicBackgroundUnionSerializer : kotlinx.serialization.KSerializer<SiteStandardThemeBasicBackgroundUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("SiteStandardThemeBasicBackgroundUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: SiteStandardThemeBasicBackgroundUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is SiteStandardThemeBasicBackgroundUnion.Rgb -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.SiteStandardThemeColorRgb.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("site.standard.theme.color#rgb")
                })
            }
            is SiteStandardThemeBasicBackgroundUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): SiteStandardThemeBasicBackgroundUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "site.standard.theme.color#rgb" -> SiteStandardThemeBasicBackgroundUnion.Rgb(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.SiteStandardThemeColorRgb.serializer(), element)
            )
            else -> SiteStandardThemeBasicBackgroundUnion.Unexpected(element)
        }
    }
}

@Serializable(with = SiteStandardThemeBasicForegroundUnionSerializer::class)
sealed interface SiteStandardThemeBasicForegroundUnion {
    @Serializable
    data class Rgb(val value: blue.catbird.petrel.generated.SiteStandardThemeColorRgb) : SiteStandardThemeBasicForegroundUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : SiteStandardThemeBasicForegroundUnion
}

object SiteStandardThemeBasicForegroundUnionSerializer : kotlinx.serialization.KSerializer<SiteStandardThemeBasicForegroundUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("SiteStandardThemeBasicForegroundUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: SiteStandardThemeBasicForegroundUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is SiteStandardThemeBasicForegroundUnion.Rgb -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.SiteStandardThemeColorRgb.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("site.standard.theme.color#rgb")
                })
            }
            is SiteStandardThemeBasicForegroundUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): SiteStandardThemeBasicForegroundUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "site.standard.theme.color#rgb" -> SiteStandardThemeBasicForegroundUnion.Rgb(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.SiteStandardThemeColorRgb.serializer(), element)
            )
            else -> SiteStandardThemeBasicForegroundUnion.Unexpected(element)
        }
    }
}

    /**
     * A simplified theme definition for publications, providing basic color customization for content display across different platforms and applications.
     */
    @Serializable
    data class SiteStandardThemeBasic(
/** Color used for links and button backgrounds. */        @SerialName("accent")
        val accent: SiteStandardThemeBasicAccentUnion,/** Color used for button text. */        @SerialName("accentForeground")
        val accentForeground: SiteStandardThemeBasicAccentForegroundUnion,/** Color used for content background. */        @SerialName("background")
        val background: SiteStandardThemeBasicBackgroundUnion,/** Color used for content text. */        @SerialName("foreground")
        val foreground: SiteStandardThemeBasicForegroundUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
