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

@Serializable
sealed interface AppBskyAgeassuranceDefsConfigRegionRulesUnion {
    @Serializable
    @SerialName("app.bsky.ageassurance.defs#AppBskyAgeassuranceDefsConfigRegionRuleDefault")
    data class AppBskyAgeassuranceDefsConfigRegionRuleDefault(val value: AppBskyAgeassuranceDefsConfigRegionRuleDefault) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    @SerialName("app.bsky.ageassurance.defs#AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge")
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge(val value: AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    @SerialName("app.bsky.ageassurance.defs#AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge")
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge(val value: AppBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    @SerialName("app.bsky.ageassurance.defs#AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge")
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge(val value: AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    @SerialName("app.bsky.ageassurance.defs#AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge")
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge(val value: AppBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    @SerialName("app.bsky.ageassurance.defs#AppBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan")
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan(val value: AppBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    @SerialName("app.bsky.ageassurance.defs#AppBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan")
    data class AppBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan(val value: AppBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan) : AppBskyAgeassuranceDefsConfigRegionRulesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyAgeassuranceDefsConfigRegionRulesUnion
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
        val lastInitiatedAt: ATProtocolDate?,        @SerialName("status")
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
        val accountCreatedAt: ATProtocolDate?    ) {
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
        val regionCode: String?,/** The minimum age (as a whole integer) required to use Bluesky in this region. */        @SerialName("minAccessAge")
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
        val regionCode: String?,/** The email used for Age Assurance. */        @SerialName("email")
        val email: String?,/** The IP address used when initiating the Age Assurance flow. */        @SerialName("initIp")
        val initIp: String?,/** The user agent used when initiating the Age Assurance flow. */        @SerialName("initUa")
        val initUa: String?,/** The IP address used when completing the Age Assurance flow. */        @SerialName("completeIp")
        val completeIp: String?,/** The user agent used when completing the Age Assurance flow. */        @SerialName("completeUa")
        val completeUa: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyAgeassuranceDefsEvent"
        }
    }
