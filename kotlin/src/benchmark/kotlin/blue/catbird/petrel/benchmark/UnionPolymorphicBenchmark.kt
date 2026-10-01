package blue.catbird.petrel.benchmark

import blue.catbird.petrel.generated.AppBskyFeedDefsPostViewEmbedUnion
import blue.catbird.petrel.generated.AppBskyFeedDefsPostViewEmbedUnionSerializer
import blue.catbird.petrel.network.DEFAULT_JSON
import kotlinx.benchmark.*
import kotlinx.serialization.json.Json

@State(Scope.Benchmark)
@Warmup(iterations = 2)
@Measurement(iterations = 3, time = 1, timeUnit = BenchmarkTimeUnit.SECONDS)
@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(BenchmarkTimeUnit.SECONDS)
open class UnionPolymorphicBenchmark {

    private val json: Json = DEFAULT_JSON

    private val imagesEmbedJson = """
    {
        "${'$'}type": "app.bsky.embed.images#view",
        "images": [
            {
                "thumb": "https://cdn.bsky.app/img/feed_thumbnail/plain/did:plc:test/bafkrei@jpeg",
                "fullsize": "https://cdn.bsky.app/img/feed_fullsize/plain/did:plc:test/bafkrei@jpeg",
                "alt": "Photo sample",
                "aspectRatio": {"width": 1200, "height": 800}
            }
        ]
    }
    """.trimIndent()

    private val externalEmbedJson = """
    {
        "${'$'}type": "app.bsky.embed.external#view",
        "external": {
            "uri": "https://example.com/article",
            "title": "Sample Article",
            "description": "Article summary description text.",
            "thumb": "https://cdn.bsky.app/thumb.jpeg"
        }
    }
    """.trimIndent()

    private lateinit var parsedImagesEmbed: AppBskyFeedDefsPostViewEmbedUnion

    @Setup
    fun setUp() {
        parsedImagesEmbed = json.decodeFromString(
            AppBskyFeedDefsPostViewEmbedUnionSerializer,
            imagesEmbedJson
        )
    }

    @Benchmark
    fun deserializeImagesEmbedUnion(): AppBskyFeedDefsPostViewEmbedUnion {
        return json.decodeFromString(
            AppBskyFeedDefsPostViewEmbedUnionSerializer,
            imagesEmbedJson
        )
    }

    @Benchmark
    fun deserializeExternalEmbedUnion(): AppBskyFeedDefsPostViewEmbedUnion {
        return json.decodeFromString(
            AppBskyFeedDefsPostViewEmbedUnionSerializer,
            externalEmbedJson
        )
    }

    @Benchmark
    fun serializeImagesEmbedUnion(): String {
        return json.encodeToString(
            AppBskyFeedDefsPostViewEmbedUnionSerializer,
            parsedImagesEmbed
        )
    }
}
