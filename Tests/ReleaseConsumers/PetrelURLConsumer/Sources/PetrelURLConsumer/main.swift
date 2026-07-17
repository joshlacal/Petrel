import Foundation
import Petrel

@main
enum PetrelURLConsumer {
    static func main() async {
        let client = await ATProtoClient(
            baseURL: URL(string: "https://example.invalid")!
        )
        _ = client
    }
}
