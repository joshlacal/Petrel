package blue.catbird.petrel.benchmark

import blue.catbird.petrel.generated.AppBskyFeedGetTimelineOutput
import blue.catbird.petrel.network.DEFAULT_JSON
import kotlinx.benchmark.*
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.decodeFromStream
import java.io.ByteArrayInputStream

@OptIn(kotlinx.serialization.ExperimentalSerializationApi::class)
@State(Scope.Benchmark)
@Warmup(iterations = 2)
@Measurement(iterations = 3, time = 1, timeUnit = BenchmarkTimeUnit.SECONDS)
@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(BenchmarkTimeUnit.SECONDS)
open class FeedDeserializationBenchmark {

    private lateinit var jsonString: String
    private lateinit var jsonBytes: ByteArray
    private lateinit var parsedTimeline: AppBskyFeedGetTimelineOutput
    private val json: Json = DEFAULT_JSON

    @Setup
    fun setUp() {
        val stream = javaClass.classLoader.getResourceAsStream("sample_timeline_50_posts.json")
            ?: error("Resource sample_timeline_50_posts.json not found in classpath")
        jsonBytes = stream.readBytes()
        jsonString = jsonBytes.decodeToString()
        parsedTimeline = json.decodeFromString(
            AppBskyFeedGetTimelineOutput.serializer(),
            jsonString
        )
    }

    @Benchmark
    fun deserializeTimelineFromString(): AppBskyFeedGetTimelineOutput {
        return json.decodeFromString(
            AppBskyFeedGetTimelineOutput.serializer(),
            jsonString
        )
    }

    @Benchmark
    fun deserializeTimelineFromStream(): AppBskyFeedGetTimelineOutput {
        return ByteArrayInputStream(jsonBytes).use { inputStream ->
            json.decodeFromStream(
                AppBskyFeedGetTimelineOutput.serializer(),
                inputStream
            )
        }
    }

    @Benchmark
    fun serializeTimelineToString(): String {
        return json.encodeToString(
            AppBskyFeedGetTimelineOutput.serializer(),
            parsedTimeline
        )
    }
}
