#!/usr/bin/env python3
"""Attribute a /usr/bin/sample capture of `--mode dagcbor-profile` (DAG-CBOR lane).

Only samples under the harness `dagcborPass` frame count. Each sample is attributed once
(exclusive weights from parse_profiles.exclusive_stacks), first to a PHASE by its ancestor
chain (priority order below, outermost decisive frame wins for nesting), then to a leaf
MECHANISM. Prints both partitions (each sums to 100%) plus top self symbols.
"""
from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import parse_profiles as pp  # noqa: E402

# Phase rules: (name, regex over symbol). Evaluated from the root of the decode downward; the
# FIRST frame (outermost) that matches any rule decides, except that rules marked "inner" can
# refine an outer decision (e.g. nested re-encode inside a typed decode).
OUTER = [
    ("hexDump (failure message)", re.compile(r"hexDump")),
    ("preflight scanner", re.compile(r"decodeCBORPreflight|PreflightScanner")),
    ("SwiftCBOR parse (CBOR AST)", re.compile(r"CBORDecoder\.|static CBOR\.decode|Util\.decodeUtf8")),
    ("CARReader / MST walk", re.compile(r"CARReader\.|MSTTraverser\.")),
    ("JSON bridge (typed default decodedFromDAGCBOR)", re.compile(r"DAGCBORJSONBridge|DAGCBOR\.decodeCBORItem|JSONCoders\.decode")),
]
# Inside fromCBOR the phase is decided by the innermost of these frames.
INNER = [
    ("fidelity: typed toCBORValue", re.compile(r"toCBORValue")),
    ("fidelity: containerFromCBORValue", re.compile(r"containerFromCBORValue")),
    ("fidelity: tolerant compare", re.compile(r"isSpecTolerant|containsKnownType|ATProtocolValueContainer\.== infix|static ATProtocolValueContainer\.==")),
    ("registry lookup", re.compile(r"TypeDecoderFactory\.decoder")),
    ("typed decode (generated init(from:) over container decoder)", re.compile(r"ATProtocolValueContainerDecoder|thunk for @escaping @callee_guaranteed @Sendable \(@in_guaranteed Decoder\)|init\(from: Decoder\)|\.init\(from:")),
]
NESTED_REENCODE = re.compile(r"ATProtocolValueContainerDecoder\.container<")
FROMCBOR = re.compile(r"ATProtocolValueContainer\.fromCBOR")

MECH = [
    ("malloc/free", re.compile(r"malloc|_free|xzm_|swift_slowAlloc|swift_slowDealloc|swift_allocObject|swift_deallocObject|<deduplicated_symbol>  \(in libsystem_malloc")),
    ("retain/release", re.compile(r"swift_retain|swift_release|swift_bridgeObjectRe|RefCounts|swift_unknownObjectRe|objc_re")),
    ("dynamic casts / metadata", re.compile(r"tryCast|swift_dynamicCast|swift_conformsToProtocol|Metadata|getGenericContext|getTypeContextDescriptor|getCache|instantiateGeneric|swift_checkMetadataState|ConcurrentReadableHashMap")),
    ("hashing / dictionary", re.compile(r"Hasher|_DictionaryStorage|__RawDictionaryStorage|NativeDictionary|Dictionary")),
    ("string building / UTF-8", re.compile(r"String|_StringGuts|_allASCII|Character|Unicode|UTF8|decodeUtf8|appendLiteral|Interpolation")),
    ("regex (identifier validation)", re.compile(r"icu::|Regex|NSRegularExpression")),
    ("array/value copies & destroy", re.compile(r"Array|memmove|memcpy|arrayDestroy|tuple_destroy|outlined|_platform_mem|ContiguousArray|ArraySlice")),
]


def classify_phase(path) -> str:
    names = [f.symbol for f in path]
    # outer phases first
    for sym in names:
        for name, rx in OUTER:
            if rx.search(sym):
                return name
    if not any(FROMCBOR.search(s) for s in names):
        if any("decodedFromDAGCBOR" in s for s in names):
            return "decodedFromDAGCBOR wrapper ([UInt8] copy etc.)"
        if any("decodeRecordCBOR" in s for s in names):
            return "decodeRecordCBOR wrapper ([UInt8] copy etc.)"
        return "harness / other"
    phase = "fromCBOR: AST -> container build (dicts, boxes, Bytes, CID)"
    nested = False
    for sym in names:
        if NESTED_REENCODE.search(sym):
            nested = True
        for name, rx in INNER:
            if rx.search(sym):
                phase = name
                break
    if nested and phase.startswith("fidelity"):
        return "typed decode: nested knownType re-encode (container(keyedBy:) on .knownType)"
    if nested:
        return "typed decode: nested knownType re-encode (container(keyedBy:) on .knownType)"
    return phase


def classify_mech(leaf: str) -> str:
    for name, rx in MECH:
        if rx.search(leaf):
            return name
    if "(in libswiftCore" in leaf:
        return "other Swift runtime"
    return "Petrel / harness code (self)"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("sample")
    ap.add_argument("--top", type=int, default=30)
    args = ap.parse_args()
    roots = pp.call_tree(Path(args.sample).read_text())
    decode_roots: list = []

    def find(node):
        if "dagcborPass" in node.symbol:
            decode_roots.append(node)
            return
        for c in node.children:
            find(c)

    for r in roots:
        find(r)
    phase, mech, leaf = Counter(), Counter(), Counter()
    total = 0
    for root in decode_roots:
        for weight, path in pp.exclusive_stacks(root):
            if weight <= 0:
                continue
            total += weight
            phase[classify_phase(path)] += weight
            mech[classify_mech(path[-1].text)] += weight
            leaf[path[-1].symbol.strip()] += weight
    print(f"samples under dagcborPass: {total}")
    for title, counter in (("PHASE (owner, sums to 100%)", phase), ("MECHANISM (leaf, sums to 100%)", mech)):
        print(f"\n== {title}")
        for k, v in counter.most_common():
            print(f"{100.0 * v / total:6.2f}%  {v:7d}  {k}")
    print(f"\n== TOP {args.top} self symbols")
    for k, v in leaf.most_common(args.top):
        print(f"{100.0 * v / total:6.2f}%  {v:7d}  {k[:150]}")


if __name__ == "__main__":
    main()
