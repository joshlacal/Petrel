// Lexicon: 1, ID: com.atproto.moderation.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
enum class Reasontype {
    @SerialName("com.atproto.moderation.defs#reasonSpam")
    COM_ATPROTO_MODERATION_DEFS#REASONSPAM,    @SerialName("com.atproto.moderation.defs#reasonViolation")
    COM_ATPROTO_MODERATION_DEFS#REASONVIOLATION,    @SerialName("com.atproto.moderation.defs#reasonMisleading")
    COM_ATPROTO_MODERATION_DEFS#REASONMISLEADING,    @SerialName("com.atproto.moderation.defs#reasonSexual")
    COM_ATPROTO_MODERATION_DEFS#REASONSEXUAL,    @SerialName("com.atproto.moderation.defs#reasonRude")
    COM_ATPROTO_MODERATION_DEFS#REASONRUDE,    @SerialName("com.atproto.moderation.defs#reasonOther")
    COM_ATPROTO_MODERATION_DEFS#REASONOTHER,    @SerialName("com.atproto.moderation.defs#reasonAppeal")
    COM_ATPROTO_MODERATION_DEFS#REASONAPPEAL,    @SerialName("tools.ozone.report.defs#reasonAppeal")
    TOOLS_OZONE_REPORT_DEFS#REASONAPPEAL,    @SerialName("tools.ozone.report.defs#reasonOther")
    TOOLS_OZONE_REPORT_DEFS#REASONOTHER,    @SerialName("tools.ozone.report.defs#reasonViolenceAnimal")
    TOOLS_OZONE_REPORT_DEFS#REASONVIOLENCEANIMAL,    @SerialName("tools.ozone.report.defs#reasonViolenceThreats")
    TOOLS_OZONE_REPORT_DEFS#REASONVIOLENCETHREATS,    @SerialName("tools.ozone.report.defs#reasonViolenceGraphicContent")
    TOOLS_OZONE_REPORT_DEFS#REASONVIOLENCEGRAPHICCONTENT,    @SerialName("tools.ozone.report.defs#reasonViolenceGlorification")
    TOOLS_OZONE_REPORT_DEFS#REASONVIOLENCEGLORIFICATION,    @SerialName("tools.ozone.report.defs#reasonViolenceExtremistContent")
    TOOLS_OZONE_REPORT_DEFS#REASONVIOLENCEEXTREMISTCONTENT,    @SerialName("tools.ozone.report.defs#reasonViolenceTrafficking")
    TOOLS_OZONE_REPORT_DEFS#REASONVIOLENCETRAFFICKING,    @SerialName("tools.ozone.report.defs#reasonViolenceOther")
    TOOLS_OZONE_REPORT_DEFS#REASONVIOLENCEOTHER,    @SerialName("tools.ozone.report.defs#reasonSexualAbuseContent")
    TOOLS_OZONE_REPORT_DEFS#REASONSEXUALABUSECONTENT,    @SerialName("tools.ozone.report.defs#reasonSexualNCII")
    TOOLS_OZONE_REPORT_DEFS#REASONSEXUALNCII,    @SerialName("tools.ozone.report.defs#reasonSexualDeepfake")
    TOOLS_OZONE_REPORT_DEFS#REASONSEXUALDEEPFAKE,    @SerialName("tools.ozone.report.defs#reasonSexualAnimal")
    TOOLS_OZONE_REPORT_DEFS#REASONSEXUALANIMAL,    @SerialName("tools.ozone.report.defs#reasonSexualUnlabeled")
    TOOLS_OZONE_REPORT_DEFS#REASONSEXUALUNLABELED,    @SerialName("tools.ozone.report.defs#reasonSexualOther")
    TOOLS_OZONE_REPORT_DEFS#REASONSEXUALOTHER,    @SerialName("tools.ozone.report.defs#reasonChildSafetyCSAM")
    TOOLS_OZONE_REPORT_DEFS#REASONCHILDSAFETYCSAM,    @SerialName("tools.ozone.report.defs#reasonChildSafetyGroom")
    TOOLS_OZONE_REPORT_DEFS#REASONCHILDSAFETYGROOM,    @SerialName("tools.ozone.report.defs#reasonChildSafetyPrivacy")
    TOOLS_OZONE_REPORT_DEFS#REASONCHILDSAFETYPRIVACY,    @SerialName("tools.ozone.report.defs#reasonChildSafetyHarassment")
    TOOLS_OZONE_REPORT_DEFS#REASONCHILDSAFETYHARASSMENT,    @SerialName("tools.ozone.report.defs#reasonChildSafetyOther")
    TOOLS_OZONE_REPORT_DEFS#REASONCHILDSAFETYOTHER,    @SerialName("tools.ozone.report.defs#reasonHarassmentTroll")
    TOOLS_OZONE_REPORT_DEFS#REASONHARASSMENTTROLL,    @SerialName("tools.ozone.report.defs#reasonHarassmentTargeted")
    TOOLS_OZONE_REPORT_DEFS#REASONHARASSMENTTARGETED,    @SerialName("tools.ozone.report.defs#reasonHarassmentHateSpeech")
    TOOLS_OZONE_REPORT_DEFS#REASONHARASSMENTHATESPEECH,    @SerialName("tools.ozone.report.defs#reasonHarassmentDoxxing")
    TOOLS_OZONE_REPORT_DEFS#REASONHARASSMENTDOXXING,    @SerialName("tools.ozone.report.defs#reasonHarassmentOther")
    TOOLS_OZONE_REPORT_DEFS#REASONHARASSMENTOTHER,    @SerialName("tools.ozone.report.defs#reasonMisleadingBot")
    TOOLS_OZONE_REPORT_DEFS#REASONMISLEADINGBOT,    @SerialName("tools.ozone.report.defs#reasonMisleadingImpersonation")
    TOOLS_OZONE_REPORT_DEFS#REASONMISLEADINGIMPERSONATION,    @SerialName("tools.ozone.report.defs#reasonMisleadingSpam")
    TOOLS_OZONE_REPORT_DEFS#REASONMISLEADINGSPAM,    @SerialName("tools.ozone.report.defs#reasonMisleadingScam")
    TOOLS_OZONE_REPORT_DEFS#REASONMISLEADINGSCAM,    @SerialName("tools.ozone.report.defs#reasonMisleadingElections")
    TOOLS_OZONE_REPORT_DEFS#REASONMISLEADINGELECTIONS,    @SerialName("tools.ozone.report.defs#reasonMisleadingOther")
    TOOLS_OZONE_REPORT_DEFS#REASONMISLEADINGOTHER,    @SerialName("tools.ozone.report.defs#reasonRuleSiteSecurity")
    TOOLS_OZONE_REPORT_DEFS#REASONRULESITESECURITY,    @SerialName("tools.ozone.report.defs#reasonRuleProhibitedSales")
    TOOLS_OZONE_REPORT_DEFS#REASONRULEPROHIBITEDSALES,    @SerialName("tools.ozone.report.defs#reasonRuleBanEvasion")
    TOOLS_OZONE_REPORT_DEFS#REASONRULEBANEVASION,    @SerialName("tools.ozone.report.defs#reasonRuleOther")
    TOOLS_OZONE_REPORT_DEFS#REASONRULEOTHER,    @SerialName("tools.ozone.report.defs#reasonSelfHarmContent")
    TOOLS_OZONE_REPORT_DEFS#REASONSELFHARMCONTENT,    @SerialName("tools.ozone.report.defs#reasonSelfHarmED")
    TOOLS_OZONE_REPORT_DEFS#REASONSELFHARMED,    @SerialName("tools.ozone.report.defs#reasonSelfHarmStunts")
    TOOLS_OZONE_REPORT_DEFS#REASONSELFHARMSTUNTS,    @SerialName("tools.ozone.report.defs#reasonSelfHarmSubstances")
    TOOLS_OZONE_REPORT_DEFS#REASONSELFHARMSUBSTANCES,    @SerialName("tools.ozone.report.defs#reasonSelfHarmOther")
    TOOLS_OZONE_REPORT_DEFS#REASONSELFHARMOTHER}

@Serializable
enum class Subjecttype {
    @SerialName("account")
    ACCOUNT,    @SerialName("record")
    RECORD,    @SerialName("chat")
    CHAT}

object ComAtprotoModerationDefs {
    const val TYPE_IDENTIFIER = "com.atproto.moderation.defs"

}
