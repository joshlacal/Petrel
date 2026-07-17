// Lexicon: 1, ID: site.standard.theme.color

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object SiteStandardThemeColorDefs {
    const val TYPE_IDENTIFIER = "site.standard.theme.color"
}

    @Serializable
    data class SiteStandardThemeColorRgb(
        @SerialName("b")
        val b: Int,        @SerialName("g")
        val g: Int,        @SerialName("r")
        val r: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#siteStandardThemeColorRgb"
        }
    }

    @Serializable
    data class SiteStandardThemeColorRgba(
        @SerialName("a")
        val a: Int,        @SerialName("b")
        val b: Int,        @SerialName("g")
        val g: Int,        @SerialName("r")
        val r: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#siteStandardThemeColorRgba"
        }
    }
