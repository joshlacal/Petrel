import Foundation

/// Utility functions for testing CID generation
public class CIDTestUtility {
    /// Tests CID generation for a post and prints diagnostic information
    public static func testCIDGeneration<T: DAGCBOREncodable>(object: T, description: String) {
        do {
            // Encode to DAGCBOR
            let encoded = try DAGCBOR.encode(object)
            print("--- CID Test for \(description) ---")
            print("Encoded bytes (\(encoded.count) bytes): \(encoded.hexDump())")

            // Generate CID
            let cid = CID.fromDAGCBOR(encoded)
            print("Generated CID: \(cid.string)")

            // Re-encode and verify deterministic encoding
            let reEncoded = try DAGCBOR.encode(object)
            let reCID = CID.fromDAGCBOR(reEncoded)

            // Verify consistency
            if cid.string == reCID.string {
                print("✅ Verified: Re-encoding produces identical CID")
            } else {
                print("❌ Error: Re-encoding produces different CID!")
                print("Re-encoded CID: \(reCID.string)")
            }

            print("---------------------------------------")

        } catch {
            print("Error testing CID generation: \(error)")
        }
    }

    /// Tests whether the CID generation is working by creating a test post
    public static func runPostCIDTest() {
        // Import necessary modules
        if let postModule = NSClassFromString("Petrel.AppBskyFeedPost") as? NSObject.Type,
           let recordClass = postModule.value(forKey: "Record") as? NSObject.Type,
           let isoDateClass = NSClassFromString("Petrel.ISO8601Date") as? NSObject.Type
        {
            do {
                // Create an ISO8601Date
                guard let date = isoDateClass.perform(
                    NSSelectorFromString("init(date:)"),
                    with: Date()
                )?.takeUnretainedValue() else {
                    print("Failed to create ISO8601Date")
                    return
                }

                // Create a simple post
                guard let post = recordClass.perform(
                    NSSelectorFromString("init(text:createdAt:langs:)"),
                    with: "Testing CID generation",
                    with: date
                )?.takeUnretainedValue() as? DAGCBOREncodable else {
                    print("Failed to create post record")
                    return
                }

                // Test CID generation with the post
                testCIDGeneration(object: post, description: "Post Record")

            } catch {
                print("Error in runPostCIDTest: \(error)")
            }
        } else {
            print("Required classes not found for CID test")
        }
    }
}
