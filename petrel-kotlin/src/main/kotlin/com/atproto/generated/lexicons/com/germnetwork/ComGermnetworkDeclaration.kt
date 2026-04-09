// Lexicon: 1, ID: com.germnetwork.declaration
// A delegate messaging id
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComGermnetworkDeclarationDefs {
    const val TYPE_IDENTIFIER = "com.germnetwork.declaration"
}

    @Serializable
    data class ComGermnetworkDeclarationMessageMe(
        @SerialName("messageMeUrl")
        val messageMeUrl: URI,        @SerialName("showButtonTo")
        val showButtonTo: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comGermnetworkDeclarationMessageMe"
        }
    }

    /**
     * A delegate messaging id
     */
    @Serializable
    data class ComGermnetworkDeclaration(
        @SerialName("version")
        val version: String,        @SerialName("currentKey")
        val currentKey: Bytes,        @SerialName("messageMe")
        val messageMe: ComGermnetworkDeclarationMessageMe? = null,        @SerialName("keyPackage")
        val keyPackage: Bytes? = null,        @SerialName("continuityProofs")
        val continuityProofs: List<JsonElement>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
