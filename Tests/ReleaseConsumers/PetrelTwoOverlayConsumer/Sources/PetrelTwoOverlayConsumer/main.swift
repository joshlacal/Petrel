import Petrel
import PetrelBluemoji
import PetrelCatbird

@main
struct PetrelTwoOverlayConsumer {
    static func main() async {
        let client = await ATProtoClient(baseURL: ATProtoClient.defaultBaseURL)

        let catbird = await client.blue.catbird
        let moji = await client.blue.moji
        _ = (catbird, moji)

        _ = BlueMojiCollectionItem.BlueMojiCollectionItemFormatsUnion.self
        _ = BlueMojiCollectionItem.BlueMojiCollectionItemStickerFormatsUnion.self
        _ = BlueMojiCollectionItem.ItemViewFormatsUnion.self
        _ = BlueMojiCollectionItem.ItemViewStickerFormatsUnion.self
        _ = BlueMojiEmbedSticker.StickerFormatsUnion.self
        _ = BlueMojiRichtextFacet.BlueMojiRichtextFacetFormatsUnion.self
        _ = BlueMojiFeedReaction.EmojiRefFormatsUnion.self
    }
}
