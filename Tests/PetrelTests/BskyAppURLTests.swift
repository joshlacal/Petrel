import Foundation
import Petrel
import Testing

@Suite("BskyAppURL")
struct BskyAppURLTests {
    private let did = "did:plc:z72i7hdynmk6r22z27h6tvur"

    @Test(
        "at:// URIs map to bsky.app pages and back",
        arguments: [
            ("at://did:plc:z72i7hdynmk6r22z27h6tvur", "https://bsky.app/profile/did:plc:z72i7hdynmk6r22z27h6tvur"),
            (
                "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3kabcdefghi2a",
                "https://bsky.app/profile/did:plc:z72i7hdynmk6r22z27h6tvur/post/3kabcdefghi2a"
            ),
            (
                "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot",
                "https://bsky.app/profile/did:plc:z72i7hdynmk6r22z27h6tvur/feed/whats-hot"
            ),
            (
                "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.graph.list/3klist",
                "https://bsky.app/profile/did:plc:z72i7hdynmk6r22z27h6tvur/lists/3klist"
            ),
            (
                "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.graph.starterpack/3kpack",
                "https://bsky.app/starter-pack/did:plc:z72i7hdynmk6r22z27h6tvur/3kpack"
            ),
            ("at://bsky.app/app.bsky.feed.post/3kabc", "https://bsky.app/profile/bsky.app/post/3kabc"),
        ]
    )
    func roundTrip(_ atURI: String, _ web: String) throws {
        let uri = try ATProtocolURI(uriString: atURI)
        let url = try #require(BskyAppURL.url(for: uri))
        #expect(url.absoluteString == web)
        #expect(BskyAppURL.atURI(from: url) == uri)
    }

    @Test("a handle can stand in for the DID in the web address")
    func handleForm() throws {
        let uri = try ATProtocolURI(uriString: "at://\(did)/app.bsky.feed.post/3kabc")
        #expect(BskyAppURL.url(for: uri, handle: "alice.example")?.absoluteString
            == "https://bsky.app/profile/alice.example/post/3kabc")
        #expect(BskyAppURL.url(for: uri, handle: "not a handle") == nil)
        #expect(BskyAppURL.url(for: uri, host: "staging.example")?.absoluteString
            == "https://staging.example/profile/\(did)/post/3kabc")
        #expect(BskyAppURL.profileURL("alice.example")?.absoluteString == "https://bsky.app/profile/alice.example")
        #expect(BskyAppURL.profileURL("../etc") == nil)
    }

    @Test("the profile record and the bare account both map to the profile page")
    func profileRecord() throws {
        let record = try ATProtocolURI(uriString: "at://\(did)/app.bsky.actor.profile/self")
        #expect(BskyAppURL.url(for: record)?.absoluteString == "https://bsky.app/profile/\(did)")
    }

    @Test("records without a page in the app have no web address")
    func unsupportedRecords() throws {
        for uri in [
            "at://\(did)/app.bsky.feed.like/3kabc",
            "at://\(did)/com.example.thing/3kabc",
            "at://\(did)/app.bsky.feed.post",
        ] {
            #expect(try BskyAppURL.url(for: ATProtocolURI(uriString: uri)) == nil)
        }
    }

    @Test("web addresses with a handle give an at:// URI with a handle authority")
    func webToATURI() throws {
        let url = try #require(URL(string: "https://bsky.app/profile/alice.example/post/3kabc?ref=share#top"))
        let uri = try #require(BskyAppURL.atURI(from: url))
        #expect(uri.uriString() == "at://alice.example/app.bsky.feed.post/3kabc")
        #expect(uri.authority == "alice.example")

        let short = try #require(URL(string: "https://bsky.app/start/alice.example/3kpack"))
        #expect(BskyAppURL.atURI(from: short)?.uriString() == "at://alice.example/app.bsky.graph.starterpack/3kpack")
    }

    @Test(
        "addresses that are not app pages are rejected",
        arguments: [
            "https://example.com/profile/alice.example/post/3kabc",
            "https://bsky.app/",
            "https://bsky.app/settings",
            "https://bsky.app/profile/alice.example/unknown/3kabc",
            "https://bsky.app/profile/alice.example/post",
            "https://bsky.app/profile/not a handle/post/3kabc",
            "https://bsky.app/profile/alice.example/post/bad%20key",
            "ftp://bsky.app/profile/alice.example",
            "https://bsky.app.evil.example/profile/alice.example",
        ]
    )
    func rejected(_ address: String) {
        guard let url = URL(string: address) else { return }
        #expect(BskyAppURL.atURI(from: url) == nil)
    }

    @Test("other hosts are accepted only when listed")
    func customHosts() throws {
        let url = try #require(URL(string: "https://staging.example/profile/alice.example"))
        #expect(BskyAppURL.atURI(from: url) == nil)
        #expect(BskyAppURL.atURI(from: url, hosts: ["staging.example"])?.uriString() == "at://alice.example")
    }
}
