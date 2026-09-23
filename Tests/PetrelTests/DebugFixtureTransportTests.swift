#if DEBUG && canImport(Network) && canImport(Security)
    import Foundation
    @testable import Petrel
    import Testing

    struct DebugFixtureTransportTests {
        private let certificate = Data(base64Encoded: "MIIDJzCCAg+gAwIBAgIUAqCihgvQwcQW7ue4nxHGvPXYx08wDQYJKoZIhvcNAQELBQAwIzEhMB8GA1UEAwwYQ2F0YmlyZCBMb2NhbCBGaXh0dXJlIENBMB4XDTI2MDkxOTE5MjcyNFoXDTI2MDkyMTE5MjcyNFowIzEhMB8GA1UEAwwYQ2F0YmlyZCBMb2NhbCBGaXh0dXJlIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmQiBFZtZIsJ6YD2c7HHSNxWi3sVQp7F1S9ynkyCIYVYTrnJUXcWG7av4ddCAOGzv8N9eJAqu6KV3M02Sf3PGSe1GOnPYNgIvsSdTIIo+dxdLs4dqyNVplUbMWjoKB0IEnSQS3c/PrJ5nLuIfBKhG2WNBB9g/BVt1+Tn28ONEBaM93jCrPp7xI4yK1mzXn73AdWZqoX66Vm31byS5V9fEJT0gc6ZdejkyozTuv/IiAvJ5ZKLyJ+mwsN/Zigz8gE6W1jzShrpL9r99qpHoM5e5Z4qLz/JivUw6yt1dA0v3XeMi8fRQ2rCJYLoaz1ekVrGVLn80znAJ9oBCmQU0hU648wIDAQABo1MwUTAdBgNVHQ4EFgQU6CtpIUGRG1qXTEDqRTl6SHUwzLcwHwYDVR0jBBgwFoAU6CtpIUGRG1qXTEDqRTl6SHUwzLcwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAFRQa2VWmClyXv0PSrXpITOsqil8RksNEMg+DYhuTj1p3N37WnnQXDhbANPPHgDRlnB/T7QV40rZ5aJAXuG1aklPFXOn7zMOQPPc7JEzSl5+a6Rl9OhvE5X84XqVlS8iqrEp0EmXOqvpdIr7uo5mczRl20pX/UfKHZcqmLtE77+0rtDS62qUpjEyaB/yPd9zuOnjYP3ak0q8W4sq1OjBKnPqFB3StojOB9epNCywna9mTouLRg3+S6oQcNgk/Odf3wMzHd+H9h54hfFOyu0ic7X40jxP5FwQtZk65WSiQu+H37N/kgolMcES1tv0rAIsgD9M1EBJclJI9aNAGw9xeXw==")!
        private func manifest() -> [String: Any] {
            [
                "fixtureOnly": true,
                "origin": "https://gateway-test.request-fixture.catbird.blue",
                "corsOrigin": "http://127.0.0.1:5173",
                "caPem": "/fixture/ca.pem",
                "tlsCertificatePem": "/fixture/server.pem",
                "tlsSpkiSha256": Data(repeating: 0, count: 32).base64EncodedString(),
                "hosts": [
                    "gateway-test.request-fixture.catbird.blue": "127.0.0.1:34567",
                    "alice-test.request-fixture.catbird.blue": "127.0.0.1:34567",
                    "bob-test.request-fixture.catbird.blue": "127.0.0.1:34567",
                    "chat.catbird.blue": "127.0.0.1:34567",
                    "public.api.bsky.app": "127.0.0.1:34567",
                ],
                "accounts": [
                    ["label": "alice", "did": "did:web:alice-test.request-fixture.catbird.blue", "deviceId": "00000000-0000-4000-8000-000000000001"],
                    ["label": "bob", "did": "did:web:bob-test.request-fixture.catbird.blue", "deviceId": "00000000-0000-4000-8000-000000000002"],
                ],
            ]
        }

        private func decode(_ object: [String: Any]) throws -> DebugFixtureTransport {
            try DebugFixtureTransport(manifest: JSONSerialization.data(withJSONObject: object), certificateDER: certificate)
        }

        @Test func exactManifestAndURLScope() throws {
            let transport = try decode(manifest())
            #expect(try transport.permits(#require(URL(string: "https://chat.catbird.blue/.well-known/did.json"))))
            for url in ["https://example.com", "http://chat.catbird.blue", "https://chat.catbird.blue:444", "https://user@chat.catbird.blue", "https://chat.catbird.blue/#fragment", "https://127.0.0.1"] {
                #expect(try !transport.permits(#require(URL(string: url))))
            }
            #expect(transport.accounts.count == 2)
        }

        @Test func rejectsUnboundedOrNonlocalManifest() throws {
            var value = manifest(); value["fixtureOnly"] = false
            #expect(throws: (any Error).self) { try decode(value) }
            value = manifest(); value["extra"] = "ignored"
            #expect(throws: (any Error).self) { try decode(value) }
            for endpoint in ["192.168.1.2:34567", "127.0.0.1:443", "127.0.0.1:034567", "localhost:34567"] {
                value = manifest(); var hosts = try #require(value["hosts"] as? [String: String])
                hosts["chat.catbird.blue"] = endpoint; value["hosts"] = hosts
                #expect(throws: (any Error).self) { try decode(value) }
            }
            value = manifest(); value["origin"] = "https://api.catbird.blue"
            #expect(throws: (any Error).self) { try decode(value) }
        }

        @Test func duplicateJSONFieldsRejectedBeforeDecoding() throws {
            let original = try JSONSerialization.data(withJSONObject: manifest(), options: [.sortedKeys])
            let text = String(decoding: original, as: UTF8.self)
            let duplicate = "{\"fixtureOnly\":true," + text.dropFirst()
            #expect(throws: (any Error).self) { try DebugFixtureTransport(manifest: Data(duplicate.utf8), certificateDER: certificate) }
            let nested = text.replacingOccurrences(of: "\"label\":\"alice\"", with: "\"label\":\"alice\",\"label\":\"alice\"")
            #expect(nested != text)
            #expect(throws: (any Error).self) { try DebugFixtureTransport(manifest: Data(nested.utf8), certificateDER: certificate) }
        }

        @Test func canonicalConnectOnly() throws {
            let valid = "CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: chat.catbird.blue:443\r\n\r\n"
            #expect(try FixtureTunnel.authority(Data(valid.utf8)) == "chat.catbird.blue")
            let invalid = [
                valid.replacingOccurrences(of: "CONNECT", with: "GET"),
                valid.replacingOccurrences(of: "chat.catbird.blue:443", with: "https://chat.catbird.blue:443"),
                valid.replacingOccurrences(of: ":443", with: ":444"),
                valid.replacingOccurrences(of: "chat.catbird.blue", with: "127.0.0.1"),
                valid.replacingOccurrences(of: "chat.catbird.blue", with: "user@chat.catbird.blue"),
                valid.replacingOccurrences(of: "\r\n\r\n", with: "\r\nHost: chat.catbird.blue:443\r\n\r\n"),
                valid.replacingOccurrences(of: "Host: chat.catbird.blue", with: "Host: other.catbird.blue"),
                valid.replacingOccurrences(of: "\r\n\r\n", with: "\r\nContent-Length: 2\r\n\r\n"),
                valid + "trailing", String(repeating: "x", count: 8193),
            ]
            for header in invalid {
                #expect(throws: (any Error).self) { try FixtureTunnel.authority(Data(header.utf8)) }
            }
        }

        /// URLSession's real CONNECT request carries a portless `Host` for the standard
        /// 443 authority (captured verbatim from a live URLSession tunnel). Both exact forms
        /// must be accepted; anything naming another host, or a portless Host paired with a
        /// non-443 CONNECT port, must still be rejected.
        @Test func portlessHostAcceptedOnlyForMatching443Authority() throws {
            let urlSessionForm = "CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: chat.catbird.blue\r\nProxy-Connection: keep-alive\r\nConnection: keep-alive\r\n\r\n"
            #expect(try FixtureTunnel.authority(Data(urlSessionForm.utf8)) == "chat.catbird.blue")
            let explicitPortForm = "CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: chat.catbird.blue:443\r\n\r\n"
            #expect(try FixtureTunnel.authority(Data(explicitPortForm.utf8)) == "chat.catbird.blue")

            let rejected = [
                // portless Host naming a different host
                "CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: other.catbird.blue\r\n\r\n",
                // portless Host with a non-443 CONNECT port
                "CONNECT chat.catbird.blue:444 HTTP/1.1\r\nHost: chat.catbird.blue\r\n\r\n",
                // Host carrying a different explicit port
                "CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: chat.catbird.blue:444\r\n\r\n",
                // two Host headers, one portless
                "CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: chat.catbird.blue\r\nHost: chat.catbird.blue:443\r\n\r\n",
            ]
            for header in rejected {
                #expect(throws: (any Error).self) { try FixtureTunnel.authority(Data(header.utf8)) }
            }
        }
    }
#endif
