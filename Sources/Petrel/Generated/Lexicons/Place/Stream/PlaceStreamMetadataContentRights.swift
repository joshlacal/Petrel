import Foundation



// lexicon: 1, id: place.stream.metadata.contentRights


public struct PlaceStreamMetadataContentRights: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.metadata.contentRights"
        public let creator: String?
        public let copyrightNotice: String?
        public let copyrightYear: Int?
        public let license: String?
        public let creditLine: String?

        public init(creator: String?, copyrightNotice: String?, copyrightYear: Int?, license: String?, creditLine: String?) {
            self.creator = creator
            self.copyrightNotice = copyrightNotice
            self.copyrightYear = copyrightYear
            self.license = license
            self.creditLine = creditLine
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.creator = try container.decodeIfPresent(String.self, forKey: .creator)
            self.copyrightNotice = try container.decodeIfPresent(String.self, forKey: .copyrightNotice)
            self.copyrightYear = try container.decodeIfPresent(Int.self, forKey: .copyrightYear)
            self.license = try container.decodeIfPresent(String.self, forKey: .license)
            self.creditLine = try container.decodeIfPresent(String.self, forKey: .creditLine)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(creator, forKey: .creator)
            try container.encodeIfPresent(copyrightNotice, forKey: .copyrightNotice)
            try container.encodeIfPresent(copyrightYear, forKey: .copyrightYear)
            try container.encodeIfPresent(license, forKey: .license)
            try container.encodeIfPresent(creditLine, forKey: .creditLine)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = creator {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = copyrightNotice {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = copyrightYear {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = license {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = creditLine {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if creator != other.creator {
                return false
            }
            if copyrightNotice != other.copyrightNotice {
                return false
            }
            if copyrightYear != other.copyrightYear {
                return false
            }
            if license != other.license {
                return false
            }
            if creditLine != other.creditLine {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            if let value = creator {
                let creatorValue = try value.toCBORValue()
                map = map.adding(key: "creator", value: creatorValue)
            }
            if let value = copyrightNotice {
                let copyrightNoticeValue = try value.toCBORValue()
                map = map.adding(key: "copyrightNotice", value: copyrightNoticeValue)
            }
            if let value = copyrightYear {
                let copyrightYearValue = try value.toCBORValue()
                map = map.adding(key: "copyrightYear", value: copyrightYearValue)
            }
            if let value = license {
                let licenseValue = try value.toCBORValue()
                map = map.adding(key: "license", value: licenseValue)
            }
            if let value = creditLine {
                let creditLineValue = try value.toCBORValue()
                map = map.adding(key: "creditLine", value: creditLineValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case creator
            case copyrightNotice
            case copyrightYear
            case license
            case creditLine
        }



}


                           

