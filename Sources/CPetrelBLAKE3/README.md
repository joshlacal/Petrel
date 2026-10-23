# Vendored BLAKE3 C implementation

This target contains the portable C implementation from BLAKE3 1.8.5. The
archive SHA-256 is `220bd81286e2a0585beac66d41ac3f4c2c33ae8a4e339fc88cf22d5e00514fe9`.
SIMD is deliberately disabled for deterministic first-lab behavior; enable it
only after the cross-language vector suite proves the optimized build.

Petrel copies the exact Swan vendored source and namespaces C identifiers with `petrel_` to coexist with hosts linking their own BLAKE3. Header filenames remain unchanged.
