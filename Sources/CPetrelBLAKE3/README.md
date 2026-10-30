# Vendored BLAKE3 C implementation

This target contains the portable C implementation from BLAKE3 1.8.7. The
archive SHA-256 is `c6782a28842b1c0478524ac06a4f2ede784038ee298d6e2162c0b089c4306a3c`.
SIMD is deliberately disabled for deterministic first-lab behavior; enable it
only after the cross-language vector suite proves the optimized build.

Petrel copies the exact Swan vendored source and namespaces C identifiers with `petrel_` to coexist with hosts linking their own BLAKE3. Header filenames remain unchanged.

Source archive: https://github.com/BLAKE3-team/BLAKE3/archive/refs/tags/1.8.7.tar.gz.
The selected portable C files are byte-identical to 1.8.5 except the version
string; the existing `petrel_` namespace transform and SIMD policy are retained.
