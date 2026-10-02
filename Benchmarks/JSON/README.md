# Petrel JSON decoding investigation

This isolated Release harness measures current Petrel models at baseline `dd02e8aee9449982c6292b718a07b1b18884f860`. It does not change the library's production decoding policy. Read `REPORT.md` for results, `PIPELINE.md` for the actual pipeline, `CORPUS.md` for fixture provenance and `SIMD-ADAPTER.md`/`ZIPPY-COMPAT.md` for candidate limitations.

## Reproduction

The delivered source bundle contains the exact otherwise-unpublished Petrel source and pinned SIMD source, plus SHA-256 manifests. Extract it, then:

```sh
cd PetrelBench/Benchmarks/JSON
python3 verify_bundle.py
./run.sh --mode correctness --out Results/recheck
./run.sh --mode structure --out Results/structure
BIN="$(swift build -c release --show-bin-path)/PetrelJSONBench"
"$BIN" --mode run --iterations 80 --out Results/run
"$BIN" --mode micro --iterations 80 --out Results/micro
"$BIN" --mode stages --iterations 80 --out Results/stages
"$BIN" --mode transport --iterations 80 --out Results/transport
"$BIN" --mode concurrency --fixture large-feed --strategy foundationFresh --workers 4 --iterations 20 --out Results/concurrency-4
"$BIN" --mode memory --fixture large-feed --strategy foundationFresh --out Results/memory
"$BIN" --mode cold --fixture large-feed --strategy foundationFresh --out Results/cold-1
"$BIN" --mode profile --fixture large-feed --strategy foundationFresh --seconds 30 --out Results/profile
```

Repeat cold/memory invocations as fresh processes. Run concurrency separately for each worker count 1,2,4,8 and each strategy when comparing process peak RSS. In a combined concurrency invocation, RSS is a cumulative process-lifetime high-water mark and must not be attributed to one cell. Load only the selected fixture before timing. Disk I/O, fixture construction, canonical equality checks and output serialization are excluded from operation latency.

On Linux use Swift 6.1+ (the comparative run uses 6.4), a C++17 compiler, and Petrel's unchanged libsecret/GLib development dependencies. The tested worker bootstraps them within its workspace. ZippyJSON is Darwin/Objective-C-only; its product is conditionally excluded on Linux. `FoundationEssentials` is not separately importable in the tested Apple SDK; on the Linux worker it aliases the same JSONDecoder type, so it is not an independent parser.

`run.sh` resolves pinned packages and applies the documented historical Zippy Bool-classification correction before building on Darwin. To reproduce the unpatched historical correctness failure, use a pristine dependency checkout and the prior harness source state; the preserved `Results/smoke` records show its exact failure. The measured patched variant is called `zippyCompat`, never historical baseline Zippy.

`python3 generate_fixtures.py` recreates the corpus from deterministic synthetic content and validates its structure against the bundled lexicons. No personal timeline, account token or private response was used. `Fixtures/manifest.json` records byte counts, SHA-256, actual model types and expected typed/unknown/union counts. `--mode correctness` also validates that Petrel's tolerant optional decoding has not silently dropped meaningful fixture fields.

## Methodology boundaries

- Ordinary baseline means the generated endpoint's fresh `JSONDecoder().decode(Output.self, from: responseData)`; network and request creation are outside the decoding timer. Fresh Foundation decoder construction remains inside that timer.
- `foundationReuse` owns one immutable-configuration decoder per worker. `foundationLocked` exercises Petrel's existing shared `JSONCoders` utility; that lock is not part of normal generated timeline endpoints.
- Full-model operation latency ends while the decoded model is retained; destruction occurs outside that individual latency. Concurrent total elapsed time includes per-operation destruction and scheduling. Micro component batches include consumption/release and report distributions of batch means.
- Warm runs use five warmups per fixture/strategy and 80 measured rounds, shuffling strategy order with a fixed RNG. Results contain every sample, median, p95, sample standard deviation, CPU time and decimal MB/s.
- Cold is the first model decode in a new process, after fixture/manifest loading; it is not application launch latency, nor an OS page-cache flush. Runtime/metadata setup is therefore included only as reached by that model path.
- `simdPreparsedModel` holds a parsed SIMD DOM outside timing and constructs actual Petrel models. It is a valid component of that candidate, not a direct measurement of Foundation's inaccessible internal parse stage.
- `JSONSerialization` includes a separate parser and an Any/Foundation object graph. Its time cannot be subtracted from JSONDecoder time to estimate Codable cost.
- The direct experiments specialize only timeline/feed/post envelope construction and conservatively gated simple records. Coverage is measured and reported. Other endpoints fall back to the corresponding generic decoder; those duplicate rows are controls, not separate optimized implementations.
- Canonical re-encoding equality is supplemented by typed fixture structure checks and malformed cases. It is strong corpus evidence, not proof of arbitrary-input equivalence. Candidate semantic differences remain recorded and disqualify a transparent production replacement.
- RSS is process peak; malloc live bytes/blocks are retained-state deltas including one-time caches, not total allocation traffic. Instrumented allocation/profile runs must never be used as uninstrumented latency samples.
- Device and OS versions are explicit. Neither macOS nor Linux numbers represent physical iPhone results. No phone app is modified.

## Native source experiments

The source snapshot is restored to baseline. Candidate binaries are build products, not committed.
The experiments are separate; restore one before activating another. They are not invoked by `run.sh`.

```sh
swift build -c release --jobs 4
mkdir -p Binaries
BIN="$(swift build -c release --show-bin-path)/PetrelJSONBench"
cp "$BIN" Binaries/PetrelJSONBench-baseline-v3
python3 experiment_string_first.py --apply
swift build -c release --jobs 4
cp "$BIN" Binaries/PetrelJSONBench-string-first
python3 experiment_string_first.py --restore
python3 experiment_base64_ascii.py --apply
swift build -c release --jobs 4
cp "$BIN" Binaries/PetrelJSONBench-base64-ascii
python3 experiment_base64_ascii.py --restore
python3 compare_variants.py --baseline Binaries/PetrelJSONBench-baseline-v3 --candidate Binaries/PetrelJSONBench-string-first --label stringFirst --out Results/string-paired
python3 compare_variants.py --baseline Binaries/PetrelJSONBench-baseline-v3 --candidate Binaries/PetrelJSONBench-base64-ascii --label base64ASCII --fixture base64-records --out Results/ascii-paired
Binaries/PetrelJSONBench-base64-ascii --mode micro --iterations 50 --out Results/ascii-micro
```

`compare_variants.py` checks canonical output bytes across binaries for all seven fixtures before timing. It then uses four rounds of 20 samples per selected fixture/binary, seeded alternating process order, and records both per-round and combined raw samples. Each process performs its ordinary five warmups. Run `--mode correctness --strategy foundationFresh` on each candidate and compare accepted values/statuses with the baseline edge matrix as well; corpus equality alone is insufficient.

`experiment_lean_bytes.py` is a separate negative-result experiment: removing the temporary arrays while retaining the Character-based classifier did not materially speed up the full endpoint. It must not be conflated with the numeric-ASCII experiment or the microbenchmark's combined lean wrapper.

To regenerate analysis tables and profile attribution:

```sh
python3 summarize_results.py
python3 parse_profiles.py
```

## Decode entry and opt-in parallel array decode (lane parallel-decode)

Generated endpoints decode through `XRPCResponseDecoding.decode` (a `@concurrent` entry with a
cancellation check and an `XRPCDecode` signpost). Two strategies exercise it; `foundationFresh` is unchanged:

- `foundationEntry`: the entry's general overload (exactly what every generated endpoint now runs by default).
- `foundationParallel`: the entry's parallel-array overload with parallel decoding enabled. Eligible outputs
  (`timeline`, `search`, `records` here) split their top-level array and decode elements on several tasks;
  others fall through to the plain decode. Tuning (library defaults when omitted):
  `--parallel-min-bytes N` (65536), `--parallel-min-elements N` (8), `--parallel-chunks N` (4 x workers),
  `--parallel-workers N` (active processor count). `run`, `concurrency`, `memory`, `cold`, `profile`,
  `canonical`, `structure` and `correctness` all accept both strategies; `run` reports process CPU time
  (all threads) next to wall time.

`--mode parallelgate [--mutations N] [--instruction-rounds N]` is a correctness gate, not a benchmark:
chunk/worker sweep (canonical bytes vs a sequential decode, parallel path must run), named malformed variants
plus deterministic random mutations (accepted values and full error reflections must match the sequential
decoder; run with `SWIFT_DETERMINISTIC_HASHING=1`), cancellation behaviour, and instructions retired per decode.
