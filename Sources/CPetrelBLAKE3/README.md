# Vendored BLAKE3 C implementation

This target contains the portable C implementation from BLAKE3 1.8.7
(tag commit `f3149ec5bb5449af877ba20377a11008ff499fa2`). The SHA-256 of
https://github.com/BLAKE3-team/BLAKE3/archive/refs/tags/1.8.7.tar.gz is
`c6782a28842b1c0478524ac06a4f2ede784038ee298d6e2162c0b089c4306a3c`.
SIMD is deliberately disabled for deterministic first-lab behavior; enable it
only after the cross-language vector suite proves the optimized build.

Petrel copies the upstream source unchanged except that it namespaces C identifiers with `petrel_` to coexist with hosts linking their own BLAKE3. Header filenames remain unchanged.

The vendored files are `c/blake3.c`, `c/blake3_dispatch.c`, `c/blake3_portable.c`,
`c/blake3.h`, `c/blake3_impl.h` and the three license files. Removing the `petrel_`
prefix from each vendored file reproduces the upstream file byte for byte. From
1.8.5 to 1.8.7 only `BLAKE3_VERSION_STRING` changed in these files.
