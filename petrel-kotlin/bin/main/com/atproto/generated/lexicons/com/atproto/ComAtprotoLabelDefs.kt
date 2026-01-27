// Lexicon: 1, ID: com.atproto.label.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoLabelDefsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.label.defs"
}

@Serializable
enum class ComAtprotoLabelDefsLabelValue {
    @SerialName("!hide")
    _HIDE,
    @SerialName("!no-promote")
    _NO_PROMOTE,
    @SerialName("!warn")
    _WARN,
    @SerialName("!no-unauthenticated")
    _NO_UNAUTHENTICATED,
    @SerialName("dmca-violation")
    DMCA_VIOLATION,
    @SerialName("doxxing")
    DOXXING,
    @SerialName("porn")
    PORN,
    @SerialName("sexual")
    SEXUAL,
    @SerialName("nudity")
    NUDITY,
    @SerialName("nsfl")
    NSFL,
    @SerialName("gore")
    GORE}

    /**
     * Metadata tag on an atproto resource (eg, repo or record).
     */
    @Serializable
    data class ComAtprotoLabelDefsLabel(
/** The AT Protocol version of the label object. */        @SerialName("ver")
        val ver: Int?,/** DID of the actor who created this label. */        @SerialName("src")
        val src: DID,/** AT URI of the record, repository (account), or other resource that this label applies to. */        @SerialName("uri")
        val uri: URI,/** Optionally, CID specifying the specific version of 'uri' resource this label applies to. */        @SerialName("cid")
        val cid: CID?,/** The short string name of the value or type of this label. */        @SerialName("val")
        val `val`: String,/** If true, this is a negation label, overwriting a previous label. */        @SerialName("neg")
        val neg: Boolean?,/** Timestamp when this label was created. */        @SerialName("cts")
        val cts: ATProtocolDate,/** Timestamp at which this label expires (no longer applies). */        @SerialName("exp")
        val exp: ATProtocolDate?,/** Signature of dag-cbor encoded label. */        @SerialName("sig")
        val sig: ByteArray?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoLabelDefsLabel"
        }
    }

    /**
     * Metadata tags on an atproto record, published by the author within the record.
     */
    @Serializable
    data class ComAtprotoLabelDefsSelfLabels(
        @SerialName("values")
        val values: List<ComAtprotoLabelDefsSelfLabel>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoLabelDefsSelfLabels"
        }
    }

    /**
     * Metadata tag on an atproto record, published by the author within the record. Note that schemas should use #selfLabels, not #selfLabel.
     */
    @Serializable
    data class ComAtprotoLabelDefsSelfLabel(
/** The short string name of the value or type of this label. */        @SerialName("val")
        val `val`: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoLabelDefsSelfLabel"
        }
    }

    /**
     * Declares a label value and its expected interpretations and behaviors.
     */
    @Serializable
    data class ComAtprotoLabelDefsLabelValueDefinition(
/** The value of the label being defined. Must only include lowercase ascii and the '-' character ([a-z-]+). */        @SerialName("identifier")
        val identifier: String,/** How should a client visually convey this label? 'inform' means neutral and informational; 'alert' means negative and warning; 'none' means show nothing. */        @SerialName("severity")
        val severity: String,/** What should this label hide in the UI, if applied? 'content' hides all of the target; 'media' hides the images/video/audio; 'none' hides nothing. */        @SerialName("blurs")
        val blurs: String,/** The default setting for this label. */        @SerialName("defaultSetting")
        val defaultSetting: String?,/** Does the user need to have adult content enabled in order to configure this label? */        @SerialName("adultOnly")
        val adultOnly: Boolean?,        @SerialName("locales")
        val locales: List<ComAtprotoLabelDefsLabelValueDefinitionStrings>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoLabelDefsLabelValueDefinition"
        }
    }

    /**
     * Strings which describe the label in the UI, localized into a specific language.
     */
    @Serializable
    data class ComAtprotoLabelDefsLabelValueDefinitionStrings(
/** The code of the language these strings are written in. */        @SerialName("lang")
        val lang: Language,/** A short human-readable name for the label. */        @SerialName("name")
        val name: String,/** A longer description of what the label means and why it might be applied. */        @SerialName("description")
        val description: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoLabelDefsLabelValueDefinitionStrings"
        }
    }
