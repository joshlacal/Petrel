import Foundation
@testable import Petrel
import Testing

@Suite("RichText Facet Conversion")
struct RichTextFacetTests {
    @Test("Link facets respect UTF-8 byte offsets")
    func linkFacetByteOffsets() throws {
        var attributed = AttributedString(
            "fair enough!! it’s good they let you migrate back to bsky.social PDSs now though"
        )
        let linkRange = attributed.range(of: "bsky.social")
        #expect(linkRange != nil)
        if let range = linkRange {
            attributed[range].link = URL(string: "https://bsky.social")
        }

        let facets = try #require(attributed.toFacets())
        #expect(facets.count == 1)

        let byteSlice = facets[0].index
        #expect(byteSlice.byteStart == 55)
        #expect(byteSlice.byteEnd == 66)
    }
}
