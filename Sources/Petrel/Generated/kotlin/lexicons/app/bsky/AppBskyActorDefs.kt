// Lexicon: 1, ID: app.bsky.actor.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyActorDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.defs"
}

@Serializable(with = AppBskyActorDefsPreferencesPreferencesUnionSerializer::class)
sealed interface AppBskyActorDefsPreferencesPreferencesUnion {
    @Serializable
    data class AdultContentPref(val value: com.atproto.generated.AppBskyActorDefsAdultContentPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class ContentLabelPref(val value: com.atproto.generated.AppBskyActorDefsContentLabelPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class SavedFeedsPref(val value: com.atproto.generated.AppBskyActorDefsSavedFeedsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class SavedFeedsPrefV2(val value: com.atproto.generated.AppBskyActorDefsSavedFeedsPrefV2) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class PersonalDetailsPref(val value: com.atproto.generated.AppBskyActorDefsPersonalDetailsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class DeclaredAgePref(val value: com.atproto.generated.AppBskyActorDefsDeclaredAgePref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class FeedViewPref(val value: com.atproto.generated.AppBskyActorDefsFeedViewPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class ThreadViewPref(val value: com.atproto.generated.AppBskyActorDefsThreadViewPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class InterestsPref(val value: com.atproto.generated.AppBskyActorDefsInterestsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class MutedWordsPref(val value: com.atproto.generated.AppBskyActorDefsMutedWordsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class HiddenPostsPref(val value: com.atproto.generated.AppBskyActorDefsHiddenPostsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class BskyAppStatePref(val value: com.atproto.generated.AppBskyActorDefsBskyAppStatePref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class LabelersPref(val value: com.atproto.generated.AppBskyActorDefsLabelersPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class PostInteractionSettingsPref(val value: com.atproto.generated.AppBskyActorDefsPostInteractionSettingsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class VerificationPrefs(val value: com.atproto.generated.AppBskyActorDefsVerificationPrefs) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class LiveEventPreferences(val value: com.atproto.generated.AppBskyActorDefsLiveEventPreferences) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyActorDefsPreferencesPreferencesUnion
}

object AppBskyActorDefsPreferencesPreferencesUnionSerializer : kotlinx.serialization.KSerializer<AppBskyActorDefsPreferencesPreferencesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyActorDefsPreferencesPreferencesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyActorDefsPreferencesPreferencesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyActorDefsPreferencesPreferencesUnion.AdultContentPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsAdultContentPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#adultContentPref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.ContentLabelPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsContentLabelPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#contentLabelPref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.SavedFeedsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsSavedFeedsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#savedFeedsPref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.SavedFeedsPrefV2 -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsSavedFeedsPrefV2.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#savedFeedsPrefV2")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.PersonalDetailsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsPersonalDetailsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#personalDetailsPref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.DeclaredAgePref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsDeclaredAgePref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#declaredAgePref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.FeedViewPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsFeedViewPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#feedViewPref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.ThreadViewPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsThreadViewPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#threadViewPref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.InterestsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsInterestsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#interestsPref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.MutedWordsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsMutedWordsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#mutedWordsPref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.HiddenPostsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsHiddenPostsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#hiddenPostsPref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.BskyAppStatePref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsBskyAppStatePref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#bskyAppStatePref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.LabelersPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsLabelersPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#labelersPref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.PostInteractionSettingsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsPostInteractionSettingsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#postInteractionSettingsPref")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.VerificationPrefs -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsVerificationPrefs.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#verificationPrefs")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.LiveEventPreferences -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsLiveEventPreferences.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#liveEventPreferences")
                })
            }
            is AppBskyActorDefsPreferencesPreferencesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyActorDefsPreferencesPreferencesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.actor.defs#adultContentPref" -> AppBskyActorDefsPreferencesPreferencesUnion.AdultContentPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsAdultContentPref.serializer(), element)
            )
            "app.bsky.actor.defs#contentLabelPref" -> AppBskyActorDefsPreferencesPreferencesUnion.ContentLabelPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsContentLabelPref.serializer(), element)
            )
            "app.bsky.actor.defs#savedFeedsPref" -> AppBskyActorDefsPreferencesPreferencesUnion.SavedFeedsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsSavedFeedsPref.serializer(), element)
            )
            "app.bsky.actor.defs#savedFeedsPrefV2" -> AppBskyActorDefsPreferencesPreferencesUnion.SavedFeedsPrefV2(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsSavedFeedsPrefV2.serializer(), element)
            )
            "app.bsky.actor.defs#personalDetailsPref" -> AppBskyActorDefsPreferencesPreferencesUnion.PersonalDetailsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsPersonalDetailsPref.serializer(), element)
            )
            "app.bsky.actor.defs#declaredAgePref" -> AppBskyActorDefsPreferencesPreferencesUnion.DeclaredAgePref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsDeclaredAgePref.serializer(), element)
            )
            "app.bsky.actor.defs#feedViewPref" -> AppBskyActorDefsPreferencesPreferencesUnion.FeedViewPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsFeedViewPref.serializer(), element)
            )
            "app.bsky.actor.defs#threadViewPref" -> AppBskyActorDefsPreferencesPreferencesUnion.ThreadViewPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsThreadViewPref.serializer(), element)
            )
            "app.bsky.actor.defs#interestsPref" -> AppBskyActorDefsPreferencesPreferencesUnion.InterestsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsInterestsPref.serializer(), element)
            )
            "app.bsky.actor.defs#mutedWordsPref" -> AppBskyActorDefsPreferencesPreferencesUnion.MutedWordsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsMutedWordsPref.serializer(), element)
            )
            "app.bsky.actor.defs#hiddenPostsPref" -> AppBskyActorDefsPreferencesPreferencesUnion.HiddenPostsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsHiddenPostsPref.serializer(), element)
            )
            "app.bsky.actor.defs#bskyAppStatePref" -> AppBskyActorDefsPreferencesPreferencesUnion.BskyAppStatePref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsBskyAppStatePref.serializer(), element)
            )
            "app.bsky.actor.defs#labelersPref" -> AppBskyActorDefsPreferencesPreferencesUnion.LabelersPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsLabelersPref.serializer(), element)
            )
            "app.bsky.actor.defs#postInteractionSettingsPref" -> AppBskyActorDefsPreferencesPreferencesUnion.PostInteractionSettingsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsPostInteractionSettingsPref.serializer(), element)
            )
            "app.bsky.actor.defs#verificationPrefs" -> AppBskyActorDefsPreferencesPreferencesUnion.VerificationPrefs(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsVerificationPrefs.serializer(), element)
            )
            "app.bsky.actor.defs#liveEventPreferences" -> AppBskyActorDefsPreferencesPreferencesUnion.LiveEventPreferences(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsLiveEventPreferences.serializer(), element)
            )
            else -> AppBskyActorDefsPreferencesPreferencesUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyActorDefsPreferencesUnionSerializer::class)
sealed interface AppBskyActorDefsPreferencesUnion {
    @Serializable
    data class AdultContentPref(val value: com.atproto.generated.AppBskyActorDefsAdultContentPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class ContentLabelPref(val value: com.atproto.generated.AppBskyActorDefsContentLabelPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class SavedFeedsPref(val value: com.atproto.generated.AppBskyActorDefsSavedFeedsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class SavedFeedsPrefV2(val value: com.atproto.generated.AppBskyActorDefsSavedFeedsPrefV2) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class PersonalDetailsPref(val value: com.atproto.generated.AppBskyActorDefsPersonalDetailsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class DeclaredAgePref(val value: com.atproto.generated.AppBskyActorDefsDeclaredAgePref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class FeedViewPref(val value: com.atproto.generated.AppBskyActorDefsFeedViewPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class ThreadViewPref(val value: com.atproto.generated.AppBskyActorDefsThreadViewPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class InterestsPref(val value: com.atproto.generated.AppBskyActorDefsInterestsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class MutedWordsPref(val value: com.atproto.generated.AppBskyActorDefsMutedWordsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class HiddenPostsPref(val value: com.atproto.generated.AppBskyActorDefsHiddenPostsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class BskyAppStatePref(val value: com.atproto.generated.AppBskyActorDefsBskyAppStatePref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class LabelersPref(val value: com.atproto.generated.AppBskyActorDefsLabelersPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class PostInteractionSettingsPref(val value: com.atproto.generated.AppBskyActorDefsPostInteractionSettingsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class VerificationPrefs(val value: com.atproto.generated.AppBskyActorDefsVerificationPrefs) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class LiveEventPreferences(val value: com.atproto.generated.AppBskyActorDefsLiveEventPreferences) : AppBskyActorDefsPreferencesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyActorDefsPreferencesUnion
}

object AppBskyActorDefsPreferencesUnionSerializer : kotlinx.serialization.KSerializer<AppBskyActorDefsPreferencesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyActorDefsPreferencesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyActorDefsPreferencesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyActorDefsPreferencesUnion.AdultContentPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsAdultContentPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#adultContentPref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.ContentLabelPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsContentLabelPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#contentLabelPref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.SavedFeedsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsSavedFeedsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#savedFeedsPref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.SavedFeedsPrefV2 -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsSavedFeedsPrefV2.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#savedFeedsPrefV2")
                })
            }
            is AppBskyActorDefsPreferencesUnion.PersonalDetailsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsPersonalDetailsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#personalDetailsPref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.DeclaredAgePref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsDeclaredAgePref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#declaredAgePref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.FeedViewPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsFeedViewPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#feedViewPref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.ThreadViewPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsThreadViewPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#threadViewPref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.InterestsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsInterestsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#interestsPref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.MutedWordsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsMutedWordsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#mutedWordsPref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.HiddenPostsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsHiddenPostsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#hiddenPostsPref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.BskyAppStatePref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsBskyAppStatePref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#bskyAppStatePref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.LabelersPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsLabelersPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#labelersPref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.PostInteractionSettingsPref -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsPostInteractionSettingsPref.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#postInteractionSettingsPref")
                })
            }
            is AppBskyActorDefsPreferencesUnion.VerificationPrefs -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsVerificationPrefs.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#verificationPrefs")
                })
            }
            is AppBskyActorDefsPreferencesUnion.LiveEventPreferences -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyActorDefsLiveEventPreferences.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.actor.defs#liveEventPreferences")
                })
            }
            is AppBskyActorDefsPreferencesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyActorDefsPreferencesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.actor.defs#adultContentPref" -> AppBskyActorDefsPreferencesUnion.AdultContentPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsAdultContentPref.serializer(), element)
            )
            "app.bsky.actor.defs#contentLabelPref" -> AppBskyActorDefsPreferencesUnion.ContentLabelPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsContentLabelPref.serializer(), element)
            )
            "app.bsky.actor.defs#savedFeedsPref" -> AppBskyActorDefsPreferencesUnion.SavedFeedsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsSavedFeedsPref.serializer(), element)
            )
            "app.bsky.actor.defs#savedFeedsPrefV2" -> AppBskyActorDefsPreferencesUnion.SavedFeedsPrefV2(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsSavedFeedsPrefV2.serializer(), element)
            )
            "app.bsky.actor.defs#personalDetailsPref" -> AppBskyActorDefsPreferencesUnion.PersonalDetailsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsPersonalDetailsPref.serializer(), element)
            )
            "app.bsky.actor.defs#declaredAgePref" -> AppBskyActorDefsPreferencesUnion.DeclaredAgePref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsDeclaredAgePref.serializer(), element)
            )
            "app.bsky.actor.defs#feedViewPref" -> AppBskyActorDefsPreferencesUnion.FeedViewPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsFeedViewPref.serializer(), element)
            )
            "app.bsky.actor.defs#threadViewPref" -> AppBskyActorDefsPreferencesUnion.ThreadViewPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsThreadViewPref.serializer(), element)
            )
            "app.bsky.actor.defs#interestsPref" -> AppBskyActorDefsPreferencesUnion.InterestsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsInterestsPref.serializer(), element)
            )
            "app.bsky.actor.defs#mutedWordsPref" -> AppBskyActorDefsPreferencesUnion.MutedWordsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsMutedWordsPref.serializer(), element)
            )
            "app.bsky.actor.defs#hiddenPostsPref" -> AppBskyActorDefsPreferencesUnion.HiddenPostsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsHiddenPostsPref.serializer(), element)
            )
            "app.bsky.actor.defs#bskyAppStatePref" -> AppBskyActorDefsPreferencesUnion.BskyAppStatePref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsBskyAppStatePref.serializer(), element)
            )
            "app.bsky.actor.defs#labelersPref" -> AppBskyActorDefsPreferencesUnion.LabelersPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsLabelersPref.serializer(), element)
            )
            "app.bsky.actor.defs#postInteractionSettingsPref" -> AppBskyActorDefsPreferencesUnion.PostInteractionSettingsPref(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsPostInteractionSettingsPref.serializer(), element)
            )
            "app.bsky.actor.defs#verificationPrefs" -> AppBskyActorDefsPreferencesUnion.VerificationPrefs(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsVerificationPrefs.serializer(), element)
            )
            "app.bsky.actor.defs#liveEventPreferences" -> AppBskyActorDefsPreferencesUnion.LiveEventPreferences(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyActorDefsLiveEventPreferences.serializer(), element)
            )
            else -> AppBskyActorDefsPreferencesUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnionSerializer::class)
sealed interface AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion {
    @Serializable
    data class MentionRule(val value: com.atproto.generated.AppBskyFeedThreadgateMentionRule) : AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion

    @Serializable
    data class FollowerRule(val value: com.atproto.generated.AppBskyFeedThreadgateFollowerRule) : AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion

    @Serializable
    data class FollowingRule(val value: com.atproto.generated.AppBskyFeedThreadgateFollowingRule) : AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion

    @Serializable
    data class ListRule(val value: com.atproto.generated.AppBskyFeedThreadgateListRule) : AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion
}

object AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnionSerializer : kotlinx.serialization.KSerializer<AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion.MentionRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateMentionRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#mentionRule")
                })
            }
            is AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion.FollowerRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowerRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#followerRule")
                })
            }
            is AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion.FollowingRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowingRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#followingRule")
                })
            }
            is AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion.ListRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateListRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#listRule")
                })
            }
            is AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.threadgate#mentionRule" -> AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion.MentionRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateMentionRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#followerRule" -> AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion.FollowerRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowerRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#followingRule" -> AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion.FollowingRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowingRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#listRule" -> AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion.ListRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateListRule.serializer(), element)
            )
            else -> AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnionSerializer::class)
sealed interface AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion {
    @Serializable
    data class DisableRule(val value: com.atproto.generated.AppBskyFeedPostgateDisableRule) : AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion
}

object AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnionSerializer : kotlinx.serialization.KSerializer<AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion.DisableRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedPostgateDisableRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.postgate#disableRule")
                })
            }
            is AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.postgate#disableRule" -> AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion.DisableRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedPostgateDisableRule.serializer(), element)
            )
            else -> AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyActorDefsStatusViewEmbedUnionSerializer::class)
sealed interface AppBskyActorDefsStatusViewEmbedUnion {
    @Serializable
    data class View(val value: com.atproto.generated.AppBskyEmbedExternalView) : AppBskyActorDefsStatusViewEmbedUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyActorDefsStatusViewEmbedUnion
}

object AppBskyActorDefsStatusViewEmbedUnionSerializer : kotlinx.serialization.KSerializer<AppBskyActorDefsStatusViewEmbedUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyActorDefsStatusViewEmbedUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyActorDefsStatusViewEmbedUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyActorDefsStatusViewEmbedUnion.View -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedExternalView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.external#view")
                })
            }
            is AppBskyActorDefsStatusViewEmbedUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyActorDefsStatusViewEmbedUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.external#view" -> AppBskyActorDefsStatusViewEmbedUnion.View(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedExternalView.serializer(), element)
            )
            else -> AppBskyActorDefsStatusViewEmbedUnion.Unexpected(element)
        }
    }
}

@Serializable
enum class AppBskyActorDefsMutedWordTarget {
    @SerialName("content")
    CONTENT,
    @SerialName("tag")
    TAG}

    @Serializable
    data class AppBskyActorDefsProfileViewBasic(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("displayName")
        val displayName: String? = null,        @SerialName("pronouns")
        val pronouns: String? = null,        @SerialName("avatar")
        val avatar: URI? = null,        @SerialName("associated")
        val associated: AppBskyActorDefsProfileAssociated? = null,        @SerialName("viewer")
        val viewer: AppBskyActorDefsViewerState? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate? = null,        @SerialName("verification")
        val verification: AppBskyActorDefsVerificationState? = null,        @SerialName("status")
        val status: AppBskyActorDefsStatusView? = null,/** Debug information for internal development */        @SerialName("debug")
        val debug: JsonElement? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileViewBasic"
        }
    }

    @Serializable
    data class AppBskyActorDefsProfileView(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("displayName")
        val displayName: String? = null,        @SerialName("pronouns")
        val pronouns: String? = null,        @SerialName("description")
        val description: String? = null,        @SerialName("avatar")
        val avatar: URI? = null,        @SerialName("associated")
        val associated: AppBskyActorDefsProfileAssociated? = null,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate? = null,        @SerialName("viewer")
        val viewer: AppBskyActorDefsViewerState? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("verification")
        val verification: AppBskyActorDefsVerificationState? = null,        @SerialName("status")
        val status: AppBskyActorDefsStatusView? = null,/** Debug information for internal development */        @SerialName("debug")
        val debug: JsonElement? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileView"
        }
    }

    @Serializable
    data class AppBskyActorDefsProfileViewDetailed(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("displayName")
        val displayName: String? = null,        @SerialName("description")
        val description: String? = null,        @SerialName("pronouns")
        val pronouns: String? = null,        @SerialName("website")
        val website: URI? = null,        @SerialName("avatar")
        val avatar: URI? = null,        @SerialName("banner")
        val banner: URI? = null,        @SerialName("followersCount")
        val followersCount: Int? = null,        @SerialName("followsCount")
        val followsCount: Int? = null,        @SerialName("postsCount")
        val postsCount: Int? = null,        @SerialName("associated")
        val associated: AppBskyActorDefsProfileAssociated? = null,        @SerialName("joinedViaStarterPack")
        val joinedViaStarterPack: AppBskyGraphDefsStarterPackViewBasic? = null,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate? = null,        @SerialName("viewer")
        val viewer: AppBskyActorDefsViewerState? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("pinnedPost")
        val pinnedPost: ComAtprotoRepoStrongRef? = null,        @SerialName("verification")
        val verification: AppBskyActorDefsVerificationState? = null,        @SerialName("status")
        val status: AppBskyActorDefsStatusView? = null,/** Debug information for internal development */        @SerialName("debug")
        val debug: JsonElement? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileViewDetailed"
        }
    }

    @Serializable
    data class AppBskyActorDefsProfileAssociated(
        @SerialName("lists")
        val lists: Int? = null,        @SerialName("feedgens")
        val feedgens: Int? = null,        @SerialName("starterPacks")
        val starterPacks: Int? = null,        @SerialName("labeler")
        val labeler: Boolean? = null,        @SerialName("chat")
        val chat: AppBskyActorDefsProfileAssociatedChat? = null,        @SerialName("activitySubscription")
        val activitySubscription: AppBskyActorDefsProfileAssociatedActivitySubscription? = null,        @SerialName("germ")
        val germ: AppBskyActorDefsProfileAssociatedGerm? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileAssociated"
        }
    }

    @Serializable
    data class AppBskyActorDefsProfileAssociatedChat(
        @SerialName("allowIncoming")
        val allowIncoming: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileAssociatedChat"
        }
    }

    @Serializable
    data class AppBskyActorDefsProfileAssociatedGerm(
        @SerialName("messageMeUrl")
        val messageMeUrl: URI,        @SerialName("showButtonTo")
        val showButtonTo: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileAssociatedGerm"
        }
    }

    @Serializable
    data class AppBskyActorDefsProfileAssociatedActivitySubscription(
        @SerialName("allowSubscriptions")
        val allowSubscriptions: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileAssociatedActivitySubscription"
        }
    }

    /**
     * Metadata about the requesting account's relationship with the subject account. Only has meaningful content for authed requests.
     */
    @Serializable
    data class AppBskyActorDefsViewerState(
        @SerialName("muted")
        val muted: Boolean? = null,        @SerialName("mutedByList")
        val mutedByList: AppBskyGraphDefsListViewBasic? = null,        @SerialName("blockedBy")
        val blockedBy: Boolean? = null,        @SerialName("blocking")
        val blocking: ATProtocolURI? = null,        @SerialName("blockingByList")
        val blockingByList: AppBskyGraphDefsListViewBasic? = null,        @SerialName("following")
        val following: ATProtocolURI? = null,        @SerialName("followedBy")
        val followedBy: ATProtocolURI? = null,/** This property is present only in selected cases, as an optimization. */        @SerialName("knownFollowers")
        val knownFollowers: AppBskyActorDefsKnownFollowers? = null,/** This property is present only in selected cases, as an optimization. */        @SerialName("activitySubscription")
        val activitySubscription: AppBskyNotificationDefsActivitySubscription? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsViewerState"
        }
    }

    /**
     * The subject's followers whom you also follow
     */
    @Serializable
    data class AppBskyActorDefsKnownFollowers(
        @SerialName("count")
        val count: Int,        @SerialName("followers")
        val followers: List<AppBskyActorDefsProfileViewBasic>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsKnownFollowers"
        }
    }

    /**
     * Represents the verification information about the user this object is attached to.
     */
    @Serializable
    data class AppBskyActorDefsVerificationState(
/** All verifications issued by trusted verifiers on behalf of this user. Verifications by untrusted verifiers are not included. */        @SerialName("verifications")
        val verifications: List<AppBskyActorDefsVerificationView>,/** The user's status as a verified account. */        @SerialName("verifiedStatus")
        val verifiedStatus: String,/** The user's status as a trusted verifier. */        @SerialName("trustedVerifierStatus")
        val trustedVerifierStatus: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsVerificationState"
        }
    }

    /**
     * An individual verification for an associated subject.
     */
    @Serializable
    data class AppBskyActorDefsVerificationView(
/** The user who issued this verification. */        @SerialName("issuer")
        val issuer: DID,/** The AT-URI of the verification record. */        @SerialName("uri")
        val uri: ATProtocolURI,/** True if the verification passes validation, otherwise false. */        @SerialName("isValid")
        val isValid: Boolean,/** Timestamp when the verification was created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsVerificationView"
        }
    }

    typealias AppBskyActorDefsPreferences = List<AppBskyActorDefsPreferencesPreferencesUnion>

    @Serializable
    data class AppBskyActorDefsAdultContentPref(
        @SerialName("enabled")
        val enabled: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsAdultContentPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsContentLabelPref(
/** Which labeler does this preference apply to? If undefined, applies globally. */        @SerialName("labelerDid")
        val labelerDid: DID? = null,        @SerialName("label")
        val label: String,        @SerialName("visibility")
        val visibility: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsContentLabelPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsSavedFeed(
        @SerialName("id")
        val id: String,        @SerialName("type")
        val type: String,        @SerialName("value")
        val value: String,        @SerialName("pinned")
        val pinned: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsSavedFeed"
        }
    }

    @Serializable
    data class AppBskyActorDefsSavedFeedsPrefV2(
        @SerialName("items")
        val items: List<AppBskyActorDefsSavedFeed>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsSavedFeedsPrefV2"
        }
    }

    @Serializable
    data class AppBskyActorDefsSavedFeedsPref(
        @SerialName("pinned")
        val pinned: List<ATProtocolURI>,        @SerialName("saved")
        val saved: List<ATProtocolURI>,        @SerialName("timelineIndex")
        val timelineIndex: Int? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsSavedFeedsPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsPersonalDetailsPref(
/** The birth date of account owner. */        @SerialName("birthDate")
        val birthDate: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsPersonalDetailsPref"
        }
    }

    /**
     * Read-only preference containing value(s) inferred from the user's declared birthdate. Absence of this preference object in the response indicates that the user has not made a declaration.
     */
    @Serializable
    data class AppBskyActorDefsDeclaredAgePref(
/** Indicates if the user has declared that they are over 13 years of age. */        @SerialName("isOverAge13")
        val isOverAge13: Boolean? = null,/** Indicates if the user has declared that they are over 16 years of age. */        @SerialName("isOverAge16")
        val isOverAge16: Boolean? = null,/** Indicates if the user has declared that they are over 18 years of age. */        @SerialName("isOverAge18")
        val isOverAge18: Boolean? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsDeclaredAgePref"
        }
    }

    @Serializable
    data class AppBskyActorDefsFeedViewPref(
/** The URI of the feed, or an identifier which describes the feed. */        @SerialName("feed")
        val feed: String,/** Hide replies in the feed. */        @SerialName("hideReplies")
        val hideReplies: Boolean? = null,/** Hide replies in the feed if they are not by followed users. */        @SerialName("hideRepliesByUnfollowed")
        val hideRepliesByUnfollowed: Boolean? = null,/** Hide replies in the feed if they do not have this number of likes. */        @SerialName("hideRepliesByLikeCount")
        val hideRepliesByLikeCount: Int? = null,/** Hide reposts in the feed. */        @SerialName("hideReposts")
        val hideReposts: Boolean? = null,/** Hide quote posts in the feed. */        @SerialName("hideQuotePosts")
        val hideQuotePosts: Boolean? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsFeedViewPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsThreadViewPref(
/** Sorting mode for threads. */        @SerialName("sort")
        val sort: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsThreadViewPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsInterestsPref(
/** A list of tags which describe the account owner's interests gathered during onboarding. */        @SerialName("tags")
        val tags: List<String>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsInterestsPref"
        }
    }

    /**
     * A word that the account owner has muted.
     */
    @Serializable
    data class AppBskyActorDefsMutedWord(
        @SerialName("id")
        val id: String? = null,/** The muted word itself. */        @SerialName("value")
        val value: String,/** The intended targets of the muted word. */        @SerialName("targets")
        val targets: List<AppBskyActorDefsMutedWordTarget>,/** Groups of users to apply the muted word to. If undefined, applies to all users. */        @SerialName("actorTarget")
        val actorTarget: String? = null,/** The date and time at which the muted word will expire and no longer be applied. */        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsMutedWord"
        }
    }

    @Serializable
    data class AppBskyActorDefsMutedWordsPref(
/** A list of words the account owner has muted. */        @SerialName("items")
        val items: List<AppBskyActorDefsMutedWord>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsMutedWordsPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsHiddenPostsPref(
/** A list of URIs of posts the account owner has hidden. */        @SerialName("items")
        val items: List<ATProtocolURI>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsHiddenPostsPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsLabelersPref(
        @SerialName("labelers")
        val labelers: List<AppBskyActorDefsLabelerPrefItem>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsLabelersPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsLabelerPrefItem(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsLabelerPrefItem"
        }
    }

    /**
     * A grab bag of state that's specific to the bsky.app program. Third-party apps shouldn't use this.
     */
    @Serializable
    data class AppBskyActorDefsBskyAppStatePref(
        @SerialName("activeProgressGuide")
        val activeProgressGuide: AppBskyActorDefsBskyAppProgressGuide? = null,/** An array of tokens which identify nudges (modals, popups, tours, highlight dots) that should be shown to the user. */        @SerialName("queuedNudges")
        val queuedNudges: List<String>? = null,/** Storage for NUXs the user has encountered. */        @SerialName("nuxs")
        val nuxs: List<AppBskyActorDefsNux>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsBskyAppStatePref"
        }
    }

    /**
     * If set, an active progress guide. Once completed, can be set to undefined. Should have unspecced fields tracking progress.
     */
    @Serializable
    data class AppBskyActorDefsBskyAppProgressGuide(
        @SerialName("guide")
        val guide: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsBskyAppProgressGuide"
        }
    }

    /**
     * A new user experiences (NUX) storage object
     */
    @Serializable
    data class AppBskyActorDefsNux(
        @SerialName("id")
        val id: String,        @SerialName("completed")
        val completed: Boolean,/** Arbitrary data for the NUX. The structure is defined by the NUX itself. Limited to 300 characters. */        @SerialName("data")
        val `data`: String? = null,/** The date and time at which the NUX will expire and should be considered completed. */        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsNux"
        }
    }

    /**
     * Preferences for how verified accounts appear in the app.
     */
    @Serializable
    data class AppBskyActorDefsVerificationPrefs(
/** Hide the blue check badges for verified accounts and trusted verifiers. */        @SerialName("hideBadges")
        val hideBadges: Boolean? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsVerificationPrefs"
        }
    }

    /**
     * Preferences for live events.
     */
    @Serializable
    data class AppBskyActorDefsLiveEventPreferences(
/** A list of feed IDs that the user has hidden from live events. */        @SerialName("hiddenFeedIds")
        val hiddenFeedIds: List<String>? = null,/** Whether to hide all feeds from live events. */        @SerialName("hideAllFeeds")
        val hideAllFeeds: Boolean? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsLiveEventPreferences"
        }
    }

    /**
     * Default post interaction settings for the account. These values should be applied as default values when creating new posts. These refs should mirror the threadgate and postgate records exactly.
     */
    @Serializable
    data class AppBskyActorDefsPostInteractionSettingsPref(
/** Matches threadgate record. List of rules defining who can reply to this users posts. If value is an empty array, no one can reply. If value is undefined, anyone can reply. */        @SerialName("threadgateAllowRules")
        val threadgateAllowRules: List<AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion>? = null,/** Matches postgate record. List of rules defining who can embed this users posts. If value is an empty array or is undefined, no particular rules apply and anyone can embed. */        @SerialName("postgateEmbeddingRules")
        val postgateEmbeddingRules: List<AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsPostInteractionSettingsPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsStatusView(
        @SerialName("uri")
        val uri: ATProtocolURI? = null,        @SerialName("cid")
        val cid: CID? = null,/** The status for the account. */        @SerialName("status")
        val status: String,        @SerialName("record")
        val record: JsonElement,/** An optional embed associated with the status. */        @SerialName("embed")
        val embed: AppBskyActorDefsStatusViewEmbedUnion? = null,/** The date when this status will expire. The application might choose to no longer return the status after expiration. */        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null,/** True if the status is not expired, false if it is expired. Only present if expiration was set. */        @SerialName("isActive")
        val isActive: Boolean? = null,/** True if the user's go-live access has been disabled by a moderator, false otherwise. */        @SerialName("isDisabled")
        val isDisabled: Boolean? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsStatusView"
        }
    }
