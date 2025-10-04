import Foundation



// lexicon: 1, id: com.atproto.moderation.defs


public struct ComAtprotoModerationDefs { 

    public static let typeIdentifier = "com.atproto.moderation.defs"



public struct ReasonType: Codable, ATProtocolCodable, ATProtocolValue {
            public let rawValue: String
            
            // Predefined constants
            // 
            public static let comatprotomoderationdefsreasonspam = ReasonType(rawValue: "com.atproto.moderation.defs#reasonSpam")
            // 
            public static let comatprotomoderationdefsreasonviolation = ReasonType(rawValue: "com.atproto.moderation.defs#reasonViolation")
            // 
            public static let comatprotomoderationdefsreasonmisleading = ReasonType(rawValue: "com.atproto.moderation.defs#reasonMisleading")
            // 
            public static let comatprotomoderationdefsreasonsexual = ReasonType(rawValue: "com.atproto.moderation.defs#reasonSexual")
            // 
            public static let comatprotomoderationdefsreasonrude = ReasonType(rawValue: "com.atproto.moderation.defs#reasonRude")
            // 
            public static let comatprotomoderationdefsreasonother = ReasonType(rawValue: "com.atproto.moderation.defs#reasonOther")
            // 
            public static let comatprotomoderationdefsreasonappeal = ReasonType(rawValue: "com.atproto.moderation.defs#reasonAppeal")
            // 
            public static let toolsozonereportdefsreasonappeal = ReasonType(rawValue: "tools.ozone.report.defs#reasonAppeal")
            // 
            public static let toolsozonereportdefsreasonviolenceanimalwelfare = ReasonType(rawValue: "tools.ozone.report.defs#reasonViolenceAnimalWelfare")
            // 
            public static let toolsozonereportdefsreasonviolencethreats = ReasonType(rawValue: "tools.ozone.report.defs#reasonViolenceThreats")
            // 
            public static let toolsozonereportdefsreasonviolencegraphiccontent = ReasonType(rawValue: "tools.ozone.report.defs#reasonViolenceGraphicContent")
            // 
            public static let toolsozonereportdefsreasonviolenceselfharm = ReasonType(rawValue: "tools.ozone.report.defs#reasonViolenceSelfHarm")
            // 
            public static let toolsozonereportdefsreasonviolenceglorification = ReasonType(rawValue: "tools.ozone.report.defs#reasonViolenceGlorification")
            // 
            public static let toolsozonereportdefsreasonviolenceextremistcontent = ReasonType(rawValue: "tools.ozone.report.defs#reasonViolenceExtremistContent")
            // 
            public static let toolsozonereportdefsreasonviolencetrafficking = ReasonType(rawValue: "tools.ozone.report.defs#reasonViolenceTrafficking")
            // 
            public static let toolsozonereportdefsreasonviolenceother = ReasonType(rawValue: "tools.ozone.report.defs#reasonViolenceOther")
            // 
            public static let toolsozonereportdefsreasonsexualabusecontent = ReasonType(rawValue: "tools.ozone.report.defs#reasonSexualAbuseContent")
            // 
            public static let toolsozonereportdefsreasonsexualncii = ReasonType(rawValue: "tools.ozone.report.defs#reasonSexualNCII")
            // 
            public static let toolsozonereportdefsreasonsexualsextortion = ReasonType(rawValue: "tools.ozone.report.defs#reasonSexualSextortion")
            // 
            public static let toolsozonereportdefsreasonsexualdeepfake = ReasonType(rawValue: "tools.ozone.report.defs#reasonSexualDeepfake")
            // 
            public static let toolsozonereportdefsreasonsexualanimal = ReasonType(rawValue: "tools.ozone.report.defs#reasonSexualAnimal")
            // 
            public static let toolsozonereportdefsreasonsexualunlabeled = ReasonType(rawValue: "tools.ozone.report.defs#reasonSexualUnlabeled")
            // 
            public static let toolsozonereportdefsreasonsexualother = ReasonType(rawValue: "tools.ozone.report.defs#reasonSexualOther")
            // 
            public static let toolsozonereportdefsreasonchildsafetycsam = ReasonType(rawValue: "tools.ozone.report.defs#reasonChildSafetyCSAM")
            // 
            public static let toolsozonereportdefsreasonchildsafetygroom = ReasonType(rawValue: "tools.ozone.report.defs#reasonChildSafetyGroom")
            // 
            public static let toolsozonereportdefsreasonchildsafetyminorprivacy = ReasonType(rawValue: "tools.ozone.report.defs#reasonChildSafetyMinorPrivacy")
            // 
            public static let toolsozonereportdefsreasonchildsafetyendangerment = ReasonType(rawValue: "tools.ozone.report.defs#reasonChildSafetyEndangerment")
            // 
            public static let toolsozonereportdefsreasonchildsafetyharassment = ReasonType(rawValue: "tools.ozone.report.defs#reasonChildSafetyHarassment")
            // 
            public static let toolsozonereportdefsreasonchildsafetypromotion = ReasonType(rawValue: "tools.ozone.report.defs#reasonChildSafetyPromotion")
            // 
            public static let toolsozonereportdefsreasonchildsafetyother = ReasonType(rawValue: "tools.ozone.report.defs#reasonChildSafetyOther")
            // 
            public static let toolsozonereportdefsreasonharassmenttroll = ReasonType(rawValue: "tools.ozone.report.defs#reasonHarassmentTroll")
            // 
            public static let toolsozonereportdefsreasonharassmenttargeted = ReasonType(rawValue: "tools.ozone.report.defs#reasonHarassmentTargeted")
            // 
            public static let toolsozonereportdefsreasonharassmenthatespeech = ReasonType(rawValue: "tools.ozone.report.defs#reasonHarassmentHateSpeech")
            // 
            public static let toolsozonereportdefsreasonharassmentdoxxing = ReasonType(rawValue: "tools.ozone.report.defs#reasonHarassmentDoxxing")
            // 
            public static let toolsozonereportdefsreasonharassmentother = ReasonType(rawValue: "tools.ozone.report.defs#reasonHarassmentOther")
            // 
            public static let toolsozonereportdefsreasonmisleadingbot = ReasonType(rawValue: "tools.ozone.report.defs#reasonMisleadingBot")
            // 
            public static let toolsozonereportdefsreasonmisleadingimpersonation = ReasonType(rawValue: "tools.ozone.report.defs#reasonMisleadingImpersonation")
            // 
            public static let toolsozonereportdefsreasonmisleadingspam = ReasonType(rawValue: "tools.ozone.report.defs#reasonMisleadingSpam")
            // 
            public static let toolsozonereportdefsreasonmisleadingscam = ReasonType(rawValue: "tools.ozone.report.defs#reasonMisleadingScam")
            // 
            public static let toolsozonereportdefsreasonmisleadingsyntheticcontent = ReasonType(rawValue: "tools.ozone.report.defs#reasonMisleadingSyntheticContent")
            // 
            public static let toolsozonereportdefsreasonmisleadingmisinformation = ReasonType(rawValue: "tools.ozone.report.defs#reasonMisleadingMisinformation")
            // 
            public static let toolsozonereportdefsreasonmisleadingother = ReasonType(rawValue: "tools.ozone.report.defs#reasonMisleadingOther")
            // 
            public static let toolsozonereportdefsreasonrulesitesecurity = ReasonType(rawValue: "tools.ozone.report.defs#reasonRuleSiteSecurity")
            // 
            public static let toolsozonereportdefsreasonrulestolencontent = ReasonType(rawValue: "tools.ozone.report.defs#reasonRuleStolenContent")
            // 
            public static let toolsozonereportdefsreasonruleprohibitedsales = ReasonType(rawValue: "tools.ozone.report.defs#reasonRuleProhibitedSales")
            // 
            public static let toolsozonereportdefsreasonrulebanevasion = ReasonType(rawValue: "tools.ozone.report.defs#reasonRuleBanEvasion")
            // 
            public static let toolsozonereportdefsreasonruleother = ReasonType(rawValue: "tools.ozone.report.defs#reasonRuleOther")
            // 
            public static let toolsozonereportdefsreasoncivicelectoralprocess = ReasonType(rawValue: "tools.ozone.report.defs#reasonCivicElectoralProcess")
            // 
            public static let toolsozonereportdefsreasoncivicdisclosure = ReasonType(rawValue: "tools.ozone.report.defs#reasonCivicDisclosure")
            // 
            public static let toolsozonereportdefsreasoncivicinterference = ReasonType(rawValue: "tools.ozone.report.defs#reasonCivicInterference")
            // 
            public static let toolsozonereportdefsreasoncivicmisinformation = ReasonType(rawValue: "tools.ozone.report.defs#reasonCivicMisinformation")
            // 
            public static let toolsozonereportdefsreasoncivicimpersonation = ReasonType(rawValue: "tools.ozone.report.defs#reasonCivicImpersonation")
            
            public init(rawValue: String) {
                self.rawValue = rawValue
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                rawValue = try container.decode(String.self)
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(rawValue)
            }
            
            public func isEqual(to other: any ATProtocolValue) -> Bool {
                guard let otherValue = other as? ReasonType else { return false }
                return self.rawValue == otherValue.rawValue
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                // For string-based enum types, we return the raw string value directly
                return rawValue
            }
            
            // Provide allCases-like functionality
            public static var predefinedValues: [ReasonType] {
                return [
                    .comatprotomoderationdefsreasonspam,
                    .comatprotomoderationdefsreasonviolation,
                    .comatprotomoderationdefsreasonmisleading,
                    .comatprotomoderationdefsreasonsexual,
                    .comatprotomoderationdefsreasonrude,
                    .comatprotomoderationdefsreasonother,
                    .comatprotomoderationdefsreasonappeal,
                    .toolsozonereportdefsreasonappeal,
                    .toolsozonereportdefsreasonviolenceanimalwelfare,
                    .toolsozonereportdefsreasonviolencethreats,
                    .toolsozonereportdefsreasonviolencegraphiccontent,
                    .toolsozonereportdefsreasonviolenceselfharm,
                    .toolsozonereportdefsreasonviolenceglorification,
                    .toolsozonereportdefsreasonviolenceextremistcontent,
                    .toolsozonereportdefsreasonviolencetrafficking,
                    .toolsozonereportdefsreasonviolenceother,
                    .toolsozonereportdefsreasonsexualabusecontent,
                    .toolsozonereportdefsreasonsexualncii,
                    .toolsozonereportdefsreasonsexualsextortion,
                    .toolsozonereportdefsreasonsexualdeepfake,
                    .toolsozonereportdefsreasonsexualanimal,
                    .toolsozonereportdefsreasonsexualunlabeled,
                    .toolsozonereportdefsreasonsexualother,
                    .toolsozonereportdefsreasonchildsafetycsam,
                    .toolsozonereportdefsreasonchildsafetygroom,
                    .toolsozonereportdefsreasonchildsafetyminorprivacy,
                    .toolsozonereportdefsreasonchildsafetyendangerment,
                    .toolsozonereportdefsreasonchildsafetyharassment,
                    .toolsozonereportdefsreasonchildsafetypromotion,
                    .toolsozonereportdefsreasonchildsafetyother,
                    .toolsozonereportdefsreasonharassmenttroll,
                    .toolsozonereportdefsreasonharassmenttargeted,
                    .toolsozonereportdefsreasonharassmenthatespeech,
                    .toolsozonereportdefsreasonharassmentdoxxing,
                    .toolsozonereportdefsreasonharassmentother,
                    .toolsozonereportdefsreasonmisleadingbot,
                    .toolsozonereportdefsreasonmisleadingimpersonation,
                    .toolsozonereportdefsreasonmisleadingspam,
                    .toolsozonereportdefsreasonmisleadingscam,
                    .toolsozonereportdefsreasonmisleadingsyntheticcontent,
                    .toolsozonereportdefsreasonmisleadingmisinformation,
                    .toolsozonereportdefsreasonmisleadingother,
                    .toolsozonereportdefsreasonrulesitesecurity,
                    .toolsozonereportdefsreasonrulestolencontent,
                    .toolsozonereportdefsreasonruleprohibitedsales,
                    .toolsozonereportdefsreasonrulebanevasion,
                    .toolsozonereportdefsreasonruleother,
                    .toolsozonereportdefsreasoncivicelectoralprocess,
                    .toolsozonereportdefsreasoncivicdisclosure,
                    .toolsozonereportdefsreasoncivicinterference,
                    .toolsozonereportdefsreasoncivicmisinformation,
                    .toolsozonereportdefsreasoncivicimpersonation,
                ]
            }
        }


public struct SubjectType: Codable, ATProtocolCodable, ATProtocolValue {
            public let rawValue: String
            
            // Predefined constants
            // 
            public static let account = SubjectType(rawValue: "account")
            // 
            public static let record = SubjectType(rawValue: "record")
            // 
            public static let chat = SubjectType(rawValue: "chat")
            
            public init(rawValue: String) {
                self.rawValue = rawValue
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                rawValue = try container.decode(String.self)
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(rawValue)
            }
            
            public func isEqual(to other: any ATProtocolValue) -> Bool {
                guard let otherValue = other as? SubjectType else { return false }
                return self.rawValue == otherValue.rawValue
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                // For string-based enum types, we return the raw string value directly
                return rawValue
            }
            
            // Provide allCases-like functionality
            public static var predefinedValues: [SubjectType] {
                return [
                    .account,
                    .record,
                    .chat,
                ]
            }
        }


}


                           
