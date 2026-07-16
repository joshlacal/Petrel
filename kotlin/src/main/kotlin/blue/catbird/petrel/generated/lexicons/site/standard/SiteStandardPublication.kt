// Lexicon: 1, ID: site.standard.publication
// A publication record representing a blog, website, or content platform. Publications serve as containers for documents and define the overall branding and settings.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object SiteStandardPublicationDefs {
    const val TYPE_IDENTIFIER = "site.standard.publication"
}

@Serializable(with = SiteStandardPublicationLabelsUnionSerializer::class)
sealed interface SiteStandardPublicationLabelsUnion {
    @Serializable
    data class SelfLabels(val value: blue.catbird.petrel.generated.ComAtprotoLabelDefsSelfLabels) : SiteStandardPublicationLabelsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : SiteStandardPublicationLabelsUnion
}

object SiteStandardPublicationLabelsUnionSerializer : kotlinx.serialization.KSerializer<SiteStandardPublicationLabelsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("SiteStandardPublicationLabelsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: SiteStandardPublicationLabelsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is SiteStandardPublicationLabelsUnion.SelfLabels -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoLabelDefsSelfLabels.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.label.defs#selfLabels")
                })
            }
            is SiteStandardPublicationLabelsUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): SiteStandardPublicationLabelsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.label.defs#selfLabels" -> SiteStandardPublicationLabelsUnion.SelfLabels(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoLabelDefsSelfLabels.serializer(), element)
            )
            else -> SiteStandardPublicationLabelsUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class SiteStandardPublicationPreferences(
/** Boolean which decides whether the publication should appear in discovery feeds. */        @SerialName("showInDiscover")
        val showInDiscover: Boolean? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#siteStandardPublicationPreferences"
        }
    }

    /**
     * A publication record representing a blog, website, or content platform. Publications serve as containers for documents and define the overall branding and settings.
     */
    @Serializable
    data class SiteStandardPublication(
/** Simplified publication theme for tools and apps to utilize when displaying content. */        @SerialName("basicTheme")
        val basicTheme: SiteStandardThemeBasic? = null,/** Brief description of the publication. */        @SerialName("description")
        val description: String? = null,/** Square image to identify the publication. Should be at least 256x256. */        @SerialName("icon")
        val icon: Blob? = null,/** Self-label values for this publication. Effectively content warnings. */        @SerialName("labels")
        val labels: SiteStandardPublicationLabelsUnion? = null,/** Name of the publication. */        @SerialName("name")
        val name: String,/** Object containing platform specific preferences (with a few shared properties). */        @SerialName("preferences")
        val preferences: SiteStandardPublicationPreferences? = null,/** Base publication url (ex: https://standard.site). The canonical document URL is formed by combining this value with the document path. */        @SerialName("url")
        val url: URI    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
