//
//  ATProtoInteropTests.swift
//
//
//  Created by Claude Code on 6/1/25.
//

import Foundation
@testable import Petrel
import Testing

/// Test suite for AT Protocol syntax validation using official interop test files
/// Based on https://github.com/bluesky-social/atproto/tree/main/interop-test-files
@Suite("AT Protocol Interop Tests")
struct ATProtoInteropTests {
    // MARK: - ATIdentifier Tests

    @Suite("ATIdentifier Validation")
    struct ATIdentifierTests {
        @Test("Valid ATIdentifiers - Handles")
        func validHandles() throws {
            let validHandles = [
                "A.ISI.EDU",
                "XX.LCS.MIT.EDU",
                "SRI-NIC.ARPA",
                "john.test",
                "jan.test",
                "a234567890123456789.test",
                "john2.test",
                "john-john.test",
                "john.bsky.app",
                "jo.hn",
                "a.co",
                "a.org",
                "joh.n",
                "j0.h0",
                "jaymome-johnber123456.test",
                "jay.mome-johnber123456.test",
                "john.test.bsky.app",
                "laptop.local",
                "laptop.arpa",
                "xn--ls8h.test",
                "xn--bcher-kva.tld",
                "expyuzz4wqqyqhjn.onion",
                "friend.expyuzz4wqqyqhjn.onion",
                "g2zyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion",
                "12345.test",
                "8.cn",
                "4chan.org",
                "4chan.o-g",
                "blah.4chan.org",
                "thing.a01",
                "120.0.0.1.com",
                "0john.test",
                "9sta--ck.com",
                "99stack.com",
                "0ohn.test",
                "john.t--t",
                "thing.0aa.thing",
                "stack.com",
                "sta-ck.com",
                "sta---ck.com",
                "sta--ck9.com",
                "stack99.com",
                "sta99ck.com",
                "google.com.uk",
                "google.co.in",
                "google.com",
                "maselkowski.pl",
                "m.maselkowski.pl",
                "xn--masekowski-d0b.pl",
                "john.t",
            ]

            for handleString in validHandles {
                #expect(throws: Never.self) {
                    try ATIdentifier(string: handleString)
                }
            }
        }

        @Test("Valid ATIdentifiers - DIDs")
        func validDIDs() throws {
            let validDIDs = [
                "did:method:val",
                "did:method:VAL",
                "did:method:val123",
                "did:method:123",
                "did:method:val-two",
                "did:method:val_two",
                "did:method:val.two",
                "did:method:val:two",
                "did:method:val%BB",
                "did:m:v",
                "did:method::::val",
                "did:method:-",
                "did:method:-:_:.:%ab",
                "did:method:.",
                "did:method:_",
                "did:method::.",
                "did:onion:2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid",
                "did:example:123456789abcdefghi",
                "did:plc:7iza6de2dwap2sbkpav7c6c6",
                "did:web:example.com",
                "did:web:localhost%3A1234",
                "did:key:zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn6N",
                "did:ethr:0xb9c5714089478a327f09197987f16f9e5d936e8a",
            ]

            for didString in validDIDs {
                #expect(throws: Never.self) {
                    try ATIdentifier(string: didString)
                }
            }
        }

        @Test("Invalid ATIdentifiers - Handles")
        func invalidHandles() {
            let invalidHandles = [
                "did:thing.test",
                "did:thing",
                "john-.test",
                "john.0",
                "john.-",
                "xn--bcher-.tld",
                "john..test",
                "jo_hn.test",
                "-john.test",
                ".john.test",
                "jo!hn.test",
                "jo%hn.test",
                "jo&hn.test",
                "jo@hn.test",
                "jo*hn.test",
                "jo|hn.test",
                "jo:hn.test",
                "jo/hn.test",
                "john.test.",
                "john",
                "john.",
                ".john",
                ".john.test",
                " john.test",
                "john.test ",
                "joh-.test",
                "john.-est",
                "john.tes-",
                "org",
                "ai",
                "gg",
                "io",
                "cn.8",
                "thing.0aa",
                "127.0.0.1",
                "192.168.0.142",
                "fe80::7325:8a97:c100:94b",
                "2600:3c03::f03c:9100:feb0:af1f",
                "-notvalid.at-all",
                "-thing.com",
            ]

            for handleString in invalidHandles {
                #expect(throws: (any Error).self) {
                    try ATIdentifier(string: handleString)
                }
            }
        }

        @Test("Invalid ATIdentifiers - DIDs")
        func invalidDIDs() {
            let invalidDIDs = [
                "did",
                "didmethodval",
                "method:did:val",
                "did:method:",
                "didmethod:val",
                "did:methodval)",
                ":did:method:val",
                "did:method:val:",
                "did:method:val%",
                "DID:method:val",
                "email@example.com",
                "@handle@example.com",
                "@handle",
                "blah",
            ]

            for didString in invalidDIDs {
                #expect(throws: (any Error).self) {
                    try ATIdentifier(string: didString)
                }
            }
        }
    }

    // MARK: - Handle Tests

    @Suite("Handle Validation")
    struct HandleTests {
        @Test("Valid Handles")
        func validHandles() throws {
            let validHandles = [
                "A.ISI.EDU",
                "XX.LCS.MIT.EDU",
                "john.test",
                "jan.test",
                "a234567890123456789.test",
                "john2.test",
                "john-john.test",
                "john.bsky.app",
                "jo.hn",
                "a.co",
                "a.org",
                "joh.n",
                "j0.h0",
                "jaymome-johnber123456.test",
                "jay.mome-johnber123456.test",
                "john.test.bsky.app",
                "laptop.local",
                "laptop.arpa",
                "xn--ls8h.test",
                "xn--bcher-kva.tld",
                "expyuzz4wqqyqhjn.onion",
                "friend.expyuzz4wqqyqhjn.onion",
                "g2zyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion",
                "12345.test",
                "8.cn",
                "4chan.org",
                "john.t",
            ]

            for handleString in validHandles {
                #expect(throws: Never.self) {
                    try Handle(handleString: handleString)
                }
            }
        }

        @Test("Invalid Handles")
        func invalidHandles() {
            let invalidHandles = [
                "john-.test",
                "john.0",
                "john.-",
                "xn--bcher-.tld",
                "john..test",
                "jo_hn.test",
                "-john.test",
                ".john.test",
                "jo!hn.test",
                "jo%hn.test",
                "jo&hn.test",
                "jo@hn.test",
                "jo*hn.test",
                "jo|hn.test",
                "jo:hn.test",
                "jo/hn.test",
                "john.test.",
                "john",
                "john.",
                ".john",
                ".john.test",
                " john.test",
                "john.test ",
                "joh-.test",
                "john.-est",
                "john.tes-",
                "org",
                "ai",
                "gg",
                "io",
                "127.0.0.1",
                "192.168.0.142",
            ]

            for handleString in invalidHandles {
                #expect(throws: (any Error).self) {
                    try Handle(handleString: handleString)
                }
            }
        }
    }

    // MARK: - DID Tests

    @Suite("DID Validation")
    struct DIDTests {
        @Test("Valid DIDs")
        func validDIDs() throws {
            let validDIDs = [
                "did:method:val",
                "did:method:VAL",
                "did:method:val123",
                "did:method:123",
                "did:method:val-two",
                "did:method:val_two",
                "did:method:val.two",
                "did:method:val:two",
                "did:method:val%BB",
                "did:m:v",
                "did:method::::val",
                "did:method:-",
                "did:method:-:_:.:%ab",
                "did:method:.",
                "did:method:_",
                "did:method::.",
                "did:onion:2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid",
                "did:example:123456789abcdefghi",
                "did:plc:7iza6de2dwap2sbkpav7c6c6",
                "did:web:example.com",
                "did:web:localhost%3A1234",
                "did:key:zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn6N",
                "did:ethr:0xb9c5714089478a327f09197987f16f9e5d936e8a",
            ]

            for didString in validDIDs {
                #expect(throws: Never.self) {
                    try DID(didString: didString)
                }
            }
        }

        @Test("Invalid DIDs")
        func invalidDIDs() {
            let invalidDIDs = [
                "did",
                "didmethodval",
                "method:did:val",
                "did:method:",
                "didmethod:val",
                "did:methodval)",
                ":did:method:val",
                "did:method:val:",
                "did:method:val%",
                "DID:method:val",
            ]

            for didString in invalidDIDs {
                #expect(throws: (any Error).self) {
                    try DID(didString: didString)
                }
            }
        }
    }

    // MARK: - NSID Tests

    @Suite("NSID Validation")
    struct NSIDTests {
        @Test("Valid NSIDs")
        func validNSIDs() throws {
            let validNSIDs = [
                "com.example.fooBar",
                "com.example.fooBarV2",
                "net.users.bob.ping",
                "a.b.c",
                "m.xn--masekowski-d0b.pl",
                "one.two.three",
                "one.two.three.four-and.FiVe",
                "one.2.three",
                "a-0.b-1.c",
                "a0.b1.cc",
                "cn.8.lex.stuff",
                "test.12345.record",
                "a01.thing.record",
                "a.0.c",
                "xn--fiqs8s.xn--fiqa61au8b7zsevnm8ak20mc4a87e.record.two",
                "a0.b1.c3",
                "com.example.f00",
                "onion.expyuzz4wqqyqhjn.spec.getThing",
                "onion.g2zyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.lex.deleteThing",
                "org.4chan.lex.getThing",
                "cn.8.lex.stuff",
                "onion.2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.lex.deleteThing",
            ]

            for nsidString in validNSIDs {
                #expect(throws: Never.self) {
                    try NSID(nsidString: nsidString)
                }
            }
        }
    }

    // MARK: - AT URI Tests

    @Suite("AT URI Validation")
    struct ATURITests {
        @Test("Valid AT URIs")
        func validATURIs() throws {
            let validURIs = [
                "at://did:plc:asdf123",
                "at://user.bsky.social",
                "at://did:plc:asdf123/com.atproto.feed.post",
                "at://did:plc:asdf123/com.atproto.feed.post/record",
                "at://did:plc:asdf123/com.atproto.feed.post/asdf123",
                "at://did:plc:asdf123/com.atproto.feed.post/a",
                "at://did:plc:asdf123/com.atproto.feed.post/asdf-123",
                "at://did:abc:123",
                "at://did:abc:123/io.nsid.someFunc/record-key",
                "at://did:abc:123/io.nsid.someFunc/self.",
                "at://did:abc:123/io.nsid.someFunc/lang:",
                "at://did:abc:123/io.nsid.someFunc/:",
                "at://did:abc:123/io.nsid.someFunc/-",
                "at://did:abc:123/io.nsid.someFunc/_",
                "at://did:abc:123/io.nsid.someFunc/~",
                "at://did:abc:123/io.nsid.someFunc/...",
                "at://did:plc:asdf123/com.atproto.feed.postV2",
            ]

            for uriString in validURIs {
                #expect(throws: Never.self) {
                    try ATProtocolURI(uriString: uriString)
                }
            }
        }
    }

    // MARK: - Record Key Tests

    @Suite("Record Key Validation")
    struct RecordKeyTests {
        @Test("Valid Record Keys")
        func validRecordKeys() throws {
            let validKeys = [
                "self",
                "example.com",
                "~1.2-3_",
                "dHJ1ZQ",
                "_",
                "literal:self",
                "pre:fix",
                ":",
                "-",
                "_",
                "~",
                "...",
                "self.",
                "lang:",
                ":lang",
            ]

            for keyString in validKeys {
                #expect(throws: Never.self) {
                    try RecordKey(keyString: keyString)
                }
            }
        }
    }

    // MARK: - TID Tests

    @Suite("TID Validation")
    struct TIDTests {
        @Test("Valid TIDs")
        func validTIDs() throws {
            let validTIDs = [
                "3jzfcijpj2z2a",
                "7777777777777",
                "3zzzzzzzzzzzz",
            ]

            for tidString in validTIDs {
                #expect(throws: Never.self) {
                    try TID(tidString: tidString)
                }
            }
        }

        @Test("TID Static Validation")
        func tidStaticValidation() {
            let validTIDs = [
                "3jzfcijpj2z2a",
                "7777777777777",
                "3zzzzzzzzzzzz",
            ]

            for tidString in validTIDs {
                #expect(TID.isValid(tidString))
            }

            let invalidTIDs = [
                "123456789012", // Too short
                "12345678901234", // Too long
                "1jzfcijpj2z2a", // Invalid first character
                "3jzfcijpj2z2!", // Invalid character
                "", // Empty
                "abcdefghijklm", // Invalid characters
            ]

            for tidString in invalidTIDs {
                #expect(!TID.isValid(tidString))
            }
        }

        @Test("TID Generator")
        func tidGenerator() async throws {
            let tid1 = await TIDGenerator.next()
            let tid2 = await TIDGenerator.next()

            // TIDs should be valid
            #expect(TID.isValid(tid1))
            #expect(TID.isValid(tid2))

            // TIDs should be different
            #expect(tid1 != tid2)

            // TIDs should be in chronological order (lexicographically)
            #expect(tid1 < tid2)

            // TID structs should work
            let tidStruct1 = await TIDGenerator.nextTID()
            let tidStruct2 = await TIDGenerator.nextTID()

            #expect(tidStruct1 < tidStruct2)
        }
    }

    // MARK: - DateTime Tests

    @Suite("DateTime Validation")
    struct DateTimeTests {
        @Test("Valid DateTime Formats")
        func validDateTimes() throws {
            let validDateTimes = [
                "1985-04-12T23:20:50.123Z",
                "1985-04-12T23:20:50.000Z",
                "2000-01-01T00:00:00.000Z",
                "1985-04-12T23:20:50.123456Z",
                "1985-04-12T23:20:50.120Z",
                "1985-04-12T23:20:50.120000Z",
                "1985-04-12T23:20:50.1235678912345Z",
                "1985-04-12T23:20:50.100Z",
                "1985-04-12T23:20:50Z",
                "1985-04-12T23:20:50.0Z",
                "1985-04-12T23:20:50.123+00:00",
                "1985-04-12T23:20:50.123-07:00",
                "1985-04-12T23:20:50.123+07:00",
                "1985-04-12T23:20:50.123+01:45",
                "0985-04-12T23:20:50.123-07:00",
                "1985-04-12T23:20:50.123-07:00",
                "0123-01-01T00:00:00.000Z",
                "1985-04-12T23:20:50.1Z",
                "1985-04-12T23:20:50.12Z",
                "1985-04-12T23:20:50.123Z",
                "1985-04-12T23:20:50.1234Z",
                "1985-04-12T23:20:50.12345Z",
                "1985-04-12T23:20:50.123456Z",
                "1985-04-12T23:20:50.1234567Z",
                "1985-04-12T23:20:50.12345678Z",
                "1985-04-12T23:20:50.123456789Z",
                "1985-04-12T23:20:50.1234567890Z",
                "1985-04-12T23:20:50.12345678901Z",
                "1985-04-12T23:20:50.123456789012Z",
                "0010-12-31T23:00:00.000Z",
                "1000-12-31T23:00:00.000Z",
                "1900-12-31T23:00:00.000Z",
                "3001-12-31T23:00:00.000Z",
            ]

            for dateTimeString in validDateTimes {
                #expect(ATProtocolDate(iso8601String: dateTimeString) != nil, "Failed to parse: \(dateTimeString)")
            }
        }

        @Test("DateTime Encoding Consistency")
        func dateTimeEncodingConsistency() throws {
            let testDate = Date(timeIntervalSince1970: 1_651_234_567.123)
            let atProtocolDate = ATProtocolDate(date: testDate)

            // The encoded string should parse back to the same date
            let encodedString = atProtocolDate.iso8601String
            let parsedDate = ATProtocolDate(iso8601String: encodedString)

            #expect(parsedDate != nil)

            // Should be very close (within millisecond precision)
            let timeDifference = abs(parsedDate!.date.timeIntervalSince1970 - testDate.timeIntervalSince1970)
            #expect(timeDifference < 0.001) // Within 1ms
        }
    }
}
