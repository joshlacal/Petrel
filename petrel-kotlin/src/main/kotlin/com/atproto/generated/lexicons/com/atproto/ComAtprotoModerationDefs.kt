// Lexicon: 1, ID: com.atproto.moderation.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoModerationDefsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.moderation.defs"
}

@Serializable
enum class ComAtprotoModerationDefsReasonType {
    @SerialName("com.atproto.moderation.defs#reasonSpam")
    COM_ATPROTO_MODERATION_DEFS_REASONSPAM,
    @SerialName("com.atproto.moderation.defs#reasonViolation")
    COM_ATPROTO_MODERATION_DEFS_REASONVIOLATION,
    @SerialName("com.atproto.moderation.defs#reasonMisleading")
    COM_ATPROTO_MODERATION_DEFS_REASONMISLEADING,
    @SerialName("com.atproto.moderation.defs#reasonSexual")
    COM_ATPROTO_MODERATION_DEFS_REASONSEXUAL,
    @SerialName("com.atproto.moderation.defs#reasonRude")
    COM_ATPROTO_MODERATION_DEFS_REASONRUDE,
    @SerialName("com.atproto.moderation.defs#reasonOther")
    COM_ATPROTO_MODERATION_DEFS_REASONOTHER,
    @SerialName("com.atproto.moderation.defs#reasonAppeal")
    COM_ATPROTO_MODERATION_DEFS_REASONAPPEAL,
    @SerialName("tools.ozone.report.defs#reasonAppeal")
    TOOLS_OZONE_REPORT_DEFS_REASONAPPEAL,
    @SerialName("tools.ozone.report.defs#reasonOther")
    TOOLS_OZONE_REPORT_DEFS_REASONOTHER,
    @SerialName("tools.ozone.report.defs#reasonViolenceAnimal")
    TOOLS_OZONE_REPORT_DEFS_REASONVIOLENCEANIMAL,
    @SerialName("tools.ozone.report.defs#reasonViolenceThreats")
    TOOLS_OZONE_REPORT_DEFS_REASONVIOLENCETHREATS,
    @SerialName("tools.ozone.report.defs#reasonViolenceGraphicContent")
    TOOLS_OZONE_REPORT_DEFS_REASONVIOLENCEGRAPHICCONTENT,
    @SerialName("tools.ozone.report.defs#reasonViolenceGlorification")
    TOOLS_OZONE_REPORT_DEFS_REASONVIOLENCEGLORIFICATION,
    @SerialName("tools.ozone.report.defs#reasonViolenceExtremistContent")
    TOOLS_OZONE_REPORT_DEFS_REASONVIOLENCEEXTREMISTCONTENT,
    @SerialName("tools.ozone.report.defs#reasonViolenceTrafficking")
    TOOLS_OZONE_REPORT_DEFS_REASONVIOLENCETRAFFICKING,
    @SerialName("tools.ozone.report.defs#reasonViolenceOther")
    TOOLS_OZONE_REPORT_DEFS_REASONVIOLENCEOTHER,
    @SerialName("tools.ozone.report.defs#reasonSexualAbuseContent")
    TOOLS_OZONE_REPORT_DEFS_REASONSEXUALABUSECONTENT,
    @SerialName("tools.ozone.report.defs#reasonSexualNCII")
    TOOLS_OZONE_REPORT_DEFS_REASONSEXUALNCII,
    @SerialName("tools.ozone.report.defs#reasonSexualDeepfake")
    TOOLS_OZONE_REPORT_DEFS_REASONSEXUALDEEPFAKE,
    @SerialName("tools.ozone.report.defs#reasonSexualAnimal")
    TOOLS_OZONE_REPORT_DEFS_REASONSEXUALANIMAL,
    @SerialName("tools.ozone.report.defs#reasonSexualUnlabeled")
    TOOLS_OZONE_REPORT_DEFS_REASONSEXUALUNLABELED,
    @SerialName("tools.ozone.report.defs#reasonSexualOther")
    TOOLS_OZONE_REPORT_DEFS_REASONSEXUALOTHER,
    @SerialName("tools.ozone.report.defs#reasonChildSafetyCSAM")
    TOOLS_OZONE_REPORT_DEFS_REASONCHILDSAFETYCSAM,
    @SerialName("tools.ozone.report.defs#reasonChildSafetyGroom")
    TOOLS_OZONE_REPORT_DEFS_REASONCHILDSAFETYGROOM,
    @SerialName("tools.ozone.report.defs#reasonChildSafetyPrivacy")
    TOOLS_OZONE_REPORT_DEFS_REASONCHILDSAFETYPRIVACY,
    @SerialName("tools.ozone.report.defs#reasonChildSafetyHarassment")
    TOOLS_OZONE_REPORT_DEFS_REASONCHILDSAFETYHARASSMENT,
    @SerialName("tools.ozone.report.defs#reasonChildSafetyOther")
    TOOLS_OZONE_REPORT_DEFS_REASONCHILDSAFETYOTHER,
    @SerialName("tools.ozone.report.defs#reasonHarassmentTroll")
    TOOLS_OZONE_REPORT_DEFS_REASONHARASSMENTTROLL,
    @SerialName("tools.ozone.report.defs#reasonHarassmentTargeted")
    TOOLS_OZONE_REPORT_DEFS_REASONHARASSMENTTARGETED,
    @SerialName("tools.ozone.report.defs#reasonHarassmentHateSpeech")
    TOOLS_OZONE_REPORT_DEFS_REASONHARASSMENTHATESPEECH,
    @SerialName("tools.ozone.report.defs#reasonHarassmentDoxxing")
    TOOLS_OZONE_REPORT_DEFS_REASONHARASSMENTDOXXING,
    @SerialName("tools.ozone.report.defs#reasonHarassmentOther")
    TOOLS_OZONE_REPORT_DEFS_REASONHARASSMENTOTHER,
    @SerialName("tools.ozone.report.defs#reasonMisleadingBot")
    TOOLS_OZONE_REPORT_DEFS_REASONMISLEADINGBOT,
    @SerialName("tools.ozone.report.defs#reasonMisleadingImpersonation")
    TOOLS_OZONE_REPORT_DEFS_REASONMISLEADINGIMPERSONATION,
    @SerialName("tools.ozone.report.defs#reasonMisleadingSpam")
    TOOLS_OZONE_REPORT_DEFS_REASONMISLEADINGSPAM,
    @SerialName("tools.ozone.report.defs#reasonMisleadingScam")
    TOOLS_OZONE_REPORT_DEFS_REASONMISLEADINGSCAM,
    @SerialName("tools.ozone.report.defs#reasonMisleadingElections")
    TOOLS_OZONE_REPORT_DEFS_REASONMISLEADINGELECTIONS,
    @SerialName("tools.ozone.report.defs#reasonMisleadingOther")
    TOOLS_OZONE_REPORT_DEFS_REASONMISLEADINGOTHER,
    @SerialName("tools.ozone.report.defs#reasonRuleSiteSecurity")
    TOOLS_OZONE_REPORT_DEFS_REASONRULESITESECURITY,
    @SerialName("tools.ozone.report.defs#reasonRuleProhibitedSales")
    TOOLS_OZONE_REPORT_DEFS_REASONRULEPROHIBITEDSALES,
    @SerialName("tools.ozone.report.defs#reasonRuleBanEvasion")
    TOOLS_OZONE_REPORT_DEFS_REASONRULEBANEVASION,
    @SerialName("tools.ozone.report.defs#reasonRuleOther")
    TOOLS_OZONE_REPORT_DEFS_REASONRULEOTHER,
    @SerialName("tools.ozone.report.defs#reasonSelfHarmContent")
    TOOLS_OZONE_REPORT_DEFS_REASONSELFHARMCONTENT,
    @SerialName("tools.ozone.report.defs#reasonSelfHarmED")
    TOOLS_OZONE_REPORT_DEFS_REASONSELFHARMED,
    @SerialName("tools.ozone.report.defs#reasonSelfHarmStunts")
    TOOLS_OZONE_REPORT_DEFS_REASONSELFHARMSTUNTS,
    @SerialName("tools.ozone.report.defs#reasonSelfHarmSubstances")
    TOOLS_OZONE_REPORT_DEFS_REASONSELFHARMSUBSTANCES,
    @SerialName("tools.ozone.report.defs#reasonSelfHarmOther")
    TOOLS_OZONE_REPORT_DEFS_REASONSELFHARMOTHER}

@Serializable
enum class ComAtprotoModerationDefsSubjectType {
    @SerialName("account")
    ACCOUNT,
    @SerialName("record")
    RECORD,
    @SerialName("chat")
    CHAT}
