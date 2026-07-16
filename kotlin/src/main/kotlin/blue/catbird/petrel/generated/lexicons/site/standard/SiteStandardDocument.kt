// Lexicon: 1, ID: site.standard.document
// A document record representing a published article, blog post, or other content. Documents can belong to a publication or exist independently.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object SiteStandardDocumentDefs {
    const val TYPE_IDENTIFIER = "site.standard.document"
}

@Serializable(with = SiteStandardDocumentContentUnionSerializer::class)
sealed interface SiteStandardDocumentContentUnion {
    @Serializable
    data class Unexpected(val value: JsonElement) : SiteStandardDocumentContentUnion
}

object SiteStandardDocumentContentUnionSerializer : kotlinx.serialization.KSerializer<SiteStandardDocumentContentUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("SiteStandardDocumentContentUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: SiteStandardDocumentContentUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is SiteStandardDocumentContentUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): SiteStandardDocumentContentUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            else -> SiteStandardDocumentContentUnion.Unexpected(element)
        }
    }
}

@Serializable(with = SiteStandardDocumentLabelsUnionSerializer::class)
sealed interface SiteStandardDocumentLabelsUnion {
    @Serializable
    data class SelfLabels(val value: blue.catbird.petrel.generated.ComAtprotoLabelDefsSelfLabels) : SiteStandardDocumentLabelsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : SiteStandardDocumentLabelsUnion
}

object SiteStandardDocumentLabelsUnionSerializer : kotlinx.serialization.KSerializer<SiteStandardDocumentLabelsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("SiteStandardDocumentLabelsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: SiteStandardDocumentLabelsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is SiteStandardDocumentLabelsUnion.SelfLabels -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoLabelDefsSelfLabels.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.label.defs#selfLabels")
                })
            }
            is SiteStandardDocumentLabelsUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): SiteStandardDocumentLabelsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.label.defs#selfLabels" -> SiteStandardDocumentLabelsUnion.SelfLabels(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoLabelDefsSelfLabels.serializer(), element)
            )
            else -> SiteStandardDocumentLabelsUnion.Unexpected(element)
        }
    }
}

@Serializable(with = SiteStandardDocumentLinksUnionSerializer::class)
sealed interface SiteStandardDocumentLinksUnion {
    @Serializable
    data class Unexpected(val value: JsonElement) : SiteStandardDocumentLinksUnion
}

object SiteStandardDocumentLinksUnionSerializer : kotlinx.serialization.KSerializer<SiteStandardDocumentLinksUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("SiteStandardDocumentLinksUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: SiteStandardDocumentLinksUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is SiteStandardDocumentLinksUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): SiteStandardDocumentLinksUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            else -> SiteStandardDocumentLinksUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class SiteStandardDocumentContributor(
        @SerialName("did")
        val did: DID,        @SerialName("displayName")
        val displayName: String? = null,        @SerialName("role")
        val role: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#siteStandardDocumentContributor"
        }
    }

    /**
     * A document record representing a published article, blog post, or other content. Documents can belong to a publication or exist independently.
     */
    @Serializable
    data class SiteStandardDocument(
/** Strong reference to a Bluesky post. Useful to keep track of comments off-platform. */        @SerialName("bskyPostRef")
        val bskyPostRef: ComAtprotoRepoStrongRef? = null,/** Open union used to define the record's content. Each entry must specify a $type and may be extended with other lexicons to support additional content formats. */        @SerialName("content")
        val content: SiteStandardDocumentContentUnion? = null,        @SerialName("contributors")
        val contributors: List<SiteStandardDocumentContributor>? = null,/** Image to used for thumbnail or cover image. Less than 1MB is size. */        @SerialName("coverImage")
        val coverImage: Blob? = null,/** A brief description or excerpt from the document. */        @SerialName("description")
        val description: String? = null,/** Self-label values for this post. Effectively content warnings. */        @SerialName("labels")
        val labels: SiteStandardDocumentLabelsUnion? = null,/** Array of values describing relationships between this document and external resources */        @SerialName("links")
        val links: SiteStandardDocumentLinksUnion? = null,/** Combine with site or publication url to construct a canonical URL to the document. Prepend with a leading slash. */        @SerialName("path")
        val path: String? = null,/** Timestamp of the documents publish time. */        @SerialName("publishedAt")
        val publishedAt: ATProtocolDate,/** Points to a publication record (at://) or a publication url (https://) for loose documents. Avoid trailing slashes. */        @SerialName("site")
        val site: URI,/** Array of strings used to tag or categorize the document. Avoid prepending tags with hashtags. */        @SerialName("tags")
        val tags: List<String>? = null,/** Plaintext representation of the documents contents. Should not contain markdown or other formatting. */        @SerialName("textContent")
        val textContent: String? = null,/** Title of the document. */        @SerialName("title")
        val title: String,/** Timestamp of the documents last edit. */        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
