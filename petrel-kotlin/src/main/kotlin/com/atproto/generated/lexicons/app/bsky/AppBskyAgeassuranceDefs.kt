// Lexicon: 1, ID: app.bsky.ageassurance.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyAgeassuranceDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.ageassurance.defs"
}

@Serializable(with = AppBskyAgeassuranceDefsConfigRegionRulesUnionSerializer::class)
sealed interface AppBskyAgeassuranceDefsConfigRegionRulesUnion {
    @Serializable
    data class ConfigRegionRuleDefault(val value: com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleDefault) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    data class ConfigRegionRuleIfDeclaredOverAge(val value: com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    data class ConfigRegionRuleIfDeclaredUnderAge(val value: com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    data class ConfigRegionRuleIfAssuredOverAge(val value: com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    data class ConfigRegionRuleIfAssuredUnderAge(val value: com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    data class ConfigRegionRuleIfAccountNewerThan(val value: com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    data class ConfigRegionRuleIfAccountOlderThan(val value: com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyAgeassuranceDefsConfigRegionRulesUnion
}

object AppBskyAgeassuranceDefsConfigRegionRulesUnionSerializer : kotlinx.serialization.KSerializer<AppBskyAgeassuranceDefsConfigRegionRulesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyAgeassuranceDefsConfigRegionRulesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyAgeassuranceDefsConfigRegionRulesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleDefault -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleDefault.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.ageassurance.defs#configRegionRuleDefault")
                })
            }
            is AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfDeclaredOverAge -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.ageassurance.defs#configRegionRuleIfDeclaredOverAge")
                })
            }
            is AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfDeclaredUnderAge -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.ageassurance.defs#configRegionRuleIfDeclaredUnderAge")
                })
            }
            is AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfAssuredOverAge -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.ageassurance.defs#configRegionRuleIfAssuredOverAge")
                })
            }
            is AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfAssuredUnderAge -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.ageassurance.defs#configRegionRuleIfAssuredUnderAge")
                })
            }
            is AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfAccountNewerThan -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.ageassurance.defs#configRegionRuleIfAccountNewerThan")
                })
            }
            is AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfAccountOlderThan -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.ageassurance.defs#configRegionRuleIfAccountOlderThan")
                })
            }
            is AppBskyAgeassuranceDefsConfigRegionRulesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyAgeassuranceDefsConfigRegionRulesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.ageassurance.defs#configRegionRuleDefault" -> AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleDefault(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleDefault.serializer(), element)
            )
            "app.bsky.ageassurance.defs#configRegionRuleIfDeclaredOverAge" -> AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfDeclaredOverAge(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge.serializer(), element)
            )
            "app.bsky.ageassurance.defs#configRegionRuleIfDeclaredUnderAge" -> AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfDeclaredUnderAge(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge.serializer(), element)
            )
            "app.bsky.ageassurance.defs#configRegionRuleIfAssuredOverAge" -> AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfAssuredOverAge(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge.serializer(), element)
            )
            "app.bsky.ageassurance.defs#configRegionRuleIfAssuredUnderAge" -> AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfAssuredUnderAge(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge.serializer(), element)
            )
            "app.bsky.ageassurance.defs#configRegionRuleIfAccountNewerThan" -> AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfAccountNewerThan(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan.serializer(), element)
            )
            "app.bsky.ageassurance.defs#configRegionRuleIfAccountOlderThan" -> AppBskyAgeassuranceDefsConfigRegionRulesUnion.ConfigRegionRuleIfAccountOlderThan(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan.serializer(), element)
            )
            else -> AppBskyAgeassuranceDefsConfigRegionRulesUnion.Unexpected(element)
        }
    }
}

@Serializable
enum class AppBskyAgeassuranceDefsAccess {
    @SerialName("unknown")
    UNKNOWN,
    @SerialName("none")
    NONE,
    @SerialName("safe")
    SAFE,
    @SerialName("full")
    FULL}

@Serializable
enum class AppBskyAgeassuranceDefsStatus {
    @SerialName("unknown")
    UNKNOWN,
    @SerialName("pending")
    PENDING,
    @SerialName("assured")
    ASSURED,
    @SerialName("blocked")
    BLOCKED}

    /**
     * The user's computed Age Assurance state.
     */
    @Serializable
    data class AppBskyAgeassuranceDefsState(
/** The timestamp when this state was last updated. */        @SerialName("lastInitiatedAt")
        val lastInitiatedAt: ATProtocolDate? = null,        @SerialName("status")
        val status: AppBskyAgeassuranceDefsStatus,        @SerialName("access")
        val access: AppBskyAgeassuranceDefsAccess    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsState"
        }
    }

    /**
     * Additional metadata needed to compute Age Assurance state client-side.
     */
    @Serializable
    data class AppBskyAgeassuranceDefsStateMetadata(
/** The account creation timestamp. */        @SerialName("accountCreatedAt")
        val accountCreatedAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsStateMetadata"
        }
    }

    @Serializable
    data class AppBskyAgeassuranceDefsConfig(
/** The per-region Age Assurance configuration. */        @SerialName("regions")
        val regions: List<AppBskyAgeassuranceDefsConfigRegion>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsConfig"
        }
    }

    /**
     * The Age Assurance configuration for a specific region.
     */
    @Serializable
    data class AppBskyAgeassuranceDefsConfigRegion(
/** The ISO 3166-1 alpha-2 country code this configuration applies to. */        @SerialName("countryCode")
        val countryCode: String,/** The ISO 3166-2 region code this configuration applies to. If omitted, the configuration applies to the entire country. */        @SerialName("regionCode")
        val regionCode: String? = null,/** The minimum age (as a whole integer) required to use Bluesky in this region. */        @SerialName("minAccessAge")
        val minAccessAge: Int,/** The ordered list of Age Assurance rules that apply to this region. Rules should be applied in order, and the first matching rule determines the access level granted. The rules array should always include a default rule as the last item. */        @SerialName("rules")
        val rules: List<AppBskyAgeassuranceDefsConfigRegionRulesUnion>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsConfigRegion"
        }
    }

    /**
     * Age Assurance rule that applies by default.
     */
    @Serializable
    data class AppBskyAgeassuranceDefsConfigRegionRuleDefault(
        @SerialName("access")
        val access: AppBskyAgeassuranceDefsAccess    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsConfigRegionRuleDefault"
        }
    }

    /**
     * Age Assurance rule that applies if the user has declared themselves equal-to or over a certain age.
     */
    @Serializable
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge(
/** The age threshold as a whole integer. */        @SerialName("age")
        val age: Int,        @SerialName("access")
        val access: AppBskyAgeassuranceDefsAccess    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge"
        }
    }

    /**
     * Age Assurance rule that applies if the user has declared themselves under a certain age.
     */
    @Serializable
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge(
/** The age threshold as a whole integer. */        @SerialName("age")
        val age: Int,        @SerialName("access")
        val access: AppBskyAgeassuranceDefsAccess    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge"
        }
    }

    /**
     * Age Assurance rule that applies if the user has been assured to be equal-to or over a certain age.
     */
    @Serializable
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge(
/** The age threshold as a whole integer. */        @SerialName("age")
        val age: Int,        @SerialName("access")
        val access: AppBskyAgeassuranceDefsAccess    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge"
        }
    }

    /**
     * Age Assurance rule that applies if the user has been assured to be under a certain age.
     */
    @Serializable
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge(
/** The age threshold as a whole integer. */        @SerialName("age")
        val age: Int,        @SerialName("access")
        val access: AppBskyAgeassuranceDefsAccess    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge"
        }
    }

    /**
     * Age Assurance rule that applies if the account is equal-to or newer than a certain date.
     */
    @Serializable
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan(
/** The date threshold as a datetime string. */        @SerialName("date")
        val date: ATProtocolDate,        @SerialName("access")
        val access: AppBskyAgeassuranceDefsAccess    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan"
        }
    }

    /**
     * Age Assurance rule that applies if the account is older than a certain date.
     */
    @Serializable
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan(
/** The date threshold as a datetime string. */        @SerialName("date")
        val date: ATProtocolDate,        @SerialName("access")
        val access: AppBskyAgeassuranceDefsAccess    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan"
        }
    }

    /**
     * Object used to store Age Assurance data in stash.
     */
    @Serializable
    data class AppBskyAgeassuranceDefsEvent(
/** The date and time of this write operation. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** The unique identifier for this instance of the Age Assurance flow, in UUID format. */        @SerialName("attemptId")
        val attemptId: String,/** The status of the Age Assurance process. */        @SerialName("status")
        val status: String,/** The access level granted based on Age Assurance data we've processed. */        @SerialName("access")
        val access: String,/** The ISO 3166-1 alpha-2 country code provided when beginning the Age Assurance flow. */        @SerialName("countryCode")
        val countryCode: String,/** The ISO 3166-2 region code provided when beginning the Age Assurance flow. */        @SerialName("regionCode")
        val regionCode: String? = null,/** The email used for Age Assurance. */        @SerialName("email")
        val email: String? = null,/** The IP address used when initiating the Age Assurance flow. */        @SerialName("initIp")
        val initIp: String? = null,/** The user agent used when initiating the Age Assurance flow. */        @SerialName("initUa")
        val initUa: String? = null,/** The IP address used when completing the Age Assurance flow. */        @SerialName("completeIp")
        val completeIp: String? = null,/** The user agent used when completing the Age Assurance flow. */        @SerialName("completeUa")
        val completeUa: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsEvent"
        }
    }
