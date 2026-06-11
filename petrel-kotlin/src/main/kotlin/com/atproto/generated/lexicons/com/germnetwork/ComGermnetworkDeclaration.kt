// Lexicon: 1, ID: com.germnetwork.declaration
// A declaration of a Germ Network account
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComGermnetworkDeclarationDefs {
    const val TYPE_IDENTIFIER = "com.germnetwork.declaration"
}

    @Serializable
    data class ComGermnetworkDeclarationMessageMe(
/** A URL to present to an account that does not have its own com.germnetwork.declaration record, must have an empty fragment component, where the app should fill in the fragment component with the DIDs of the two accounts who wish to message each other */        @SerialName("messageMeUrl")
        val messageMeUrl: URI,/** The policy of who can message the account, this value is included in the keyPackage, but is duplicated here to allow applications to decide if they should show a 'Message on Germ' button to the viewer. */        @SerialName("showButtonTo")
        val showButtonTo: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comGermnetworkDeclarationMessageMe"
        }
    }

    /**
     * A declaration of a Germ Network account
     */
    @Serializable
    data class ComGermnetworkDeclaration(
/** Semver version number, without pre-release or build information, for the format of opaque content */        @SerialName("version")
        val version: String,/** Opaque value, an ed25519 public key prefixed with a byte enum */        @SerialName("currentKey")
        val currentKey: Bytes,/** Controls who can message this account */        @SerialName("messageMe")
        val messageMe: ComGermnetworkDeclarationMessageMe? = null,/** Opaque value, contains MLS KeyPackage(s), and other signature data, and is signed by the currentKey */        @SerialName("keyPackage")
        val keyPackage: Bytes? = null,/** Array of opaque values to allow for key rolling */        @SerialName("continuityProofs")
        val continuityProofs: List<JsonElement>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
