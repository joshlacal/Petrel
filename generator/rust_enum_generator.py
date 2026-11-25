"""
Rust enum and union generator for AT Protocol Lexicons.

Note on Decision #4: generated types MUST NOT derive `serde::Serialize` or
`serde::Deserialize` and MUST NOT use `#[serde(flatten)]`. String enums emit
hand-written `Serialize`/`Deserialize` impls directly; unions emit the enum
definition and record variant metadata for WP-G4's `petrel-core` serde bridge.
"""
from __future__ import annotations

from collections import Counter
import re
from typing import Any, Dict, List, Optional, Set, Tuple

from rust_type_converter import rust_pascal_case
from utils import normalize_ref

_VARIANT_NON_ALNUM_RE = re.compile(r"[^A-Za-z0-9]+")


def _segment_pascal(segment: str) -> str:
    """Convert one NSID/fragment segment to raw PascalCase without leading underscores."""
    parts = [part for part in _VARIANT_NON_ALNUM_RE.split(segment) if part]
    return "".join(part[0].upper() + part[1:] for part in parts)


def rust_string_literal(value: str) -> str:
    """Escape an arbitrary Python string as a Rust double-quoted string literal."""
    escapes = {
        "\\": "\\\\",
        '"': '\\"',
        "\n": "\\n",
        "\r": "\\r",
        "\t": "\\t",
        "\0": "\\0",
    }
    encoded: List[str] = []
    for char in value:
        if char in escapes:
            encoded.append(escapes[char])
        elif ord(char) < 0x20 or ord(char) == 0x7F or char in ("\u2028", "\u2029"):
            encoded.append(f"\\u{{{ord(char):x}}}")
        else:
            encoded.append(char)
    return f'"{"".join(encoded)}"'


def _injective_variant_identifier(value: str) -> str:
    """Injective UpperCamelCase Rust variant identifier encoding for arbitrary wire strings."""
    encoded = "".join(
        char if char.isascii() and char.isalnum() and char != "U" else f"U{ord(char):x}u"
        for char in value
    )
    return f"Value{encoded}"


def _clean_variant_identifier(value: str, used: Set[str], *, reserved: Set[str] = frozenset({"Self"})) -> str:
    """Return a valid, collision-free PascalCase Rust enum variant identifier."""
    candidate = rust_pascal_case(value)
    # Only use the clean PascalCase name when the wire string starts with ASCII
    # alphanumeric and consists only of ASCII alphanumerics + standard separators,
    # and does not collide with an already-used variant or reserved name.
    is_ascii_clean = bool(value) and all(
        c.isascii() and (c.isalnum() or c in "-_.:/#!") for c in value
    ) and any(c.isascii() and c.isalnum() for c in value)
    if (
        is_ascii_clean
        and candidate not in used
        and candidate not in reserved
        and not candidate.startswith("_")
    ):
        used.add(candidate)
        return candidate

    fallback = _injective_variant_identifier(value)
    candidate_fallback = fallback
    suffix = 2
    while candidate_fallback in used or candidate_fallback in reserved:
        candidate_fallback = f"{fallback}Alt{suffix}"
        suffix += 1
    used.add(candidate_fallback)
    return candidate_fallback


class RustEnumGenerator:
    """Generates Rust enums for Lexicon unions, knownValues, and closed string enums."""

    def __init__(self, code_generator):
        self.code_generator = code_generator
        self.generated_unions: Set[str] = set()
        self.generated_known_values: Set[str] = set()
        self.unions: Dict[str, Dict[str, Any]] = {}
        self.known_values_enums: Dict[str, str] = {}
        self.closed_enums: Dict[str, str] = {}
        self.closed_enums_by_identity: Dict[Any, Tuple[str, Tuple[str, ...]]] = {}
        self.closed_enum_identity_by_name: Dict[str, Any] = {}
        self.enums_code: List[str] = []

    def _validate_union_refs(
        self, union_name: str, raw_refs: List[str], *, closed: bool
    ) -> List[str]:
        lexicon_id = self.code_generator.lexicon_id
        if closed and not raw_refs:
            raise ValueError(f"{lexicon_id}: closed union '{union_name}' has no refs")

        normalized_tags = [normalize_ref(ref, lexicon_id) for ref in raw_refs]
        if closed:
            seen: Set[str] = set()
            for tag in normalized_tags:
                if tag in seen:
                    raise ValueError(
                        f"{lexicon_id}: closed union '{union_name}' has duplicate ref '{tag}'"
                    )
                seen.add(tag)
        return normalized_tags

    @staticmethod
    def _short_variant_name(normalized_ref: str) -> str:
        if "#" in normalized_ref:
            _, fragment = normalized_ref.split("#", 1)
            raw = _segment_pascal(fragment)
        else:
            raw = _segment_pascal(normalized_ref.rsplit(".", 1)[-1])
        if not raw:
            return "Variant"
        return f"V{raw}" if raw[0].isdigit() else raw

    @staticmethod
    def _disambiguate_variant_names(
        normalized_refs: List[str], *, reserved: Set[str]
    ) -> List[str]:
        """Assign unique PascalCase variant names, prefixing NSID segments on collision.

        Ports `mls-ds/codegen`'s `disambiguate_union_variants`: when e.g.
        `com.atproto.personalspace.policy`, `com.atproto.memberspace.policy`, and
        `com.atproto.managedspace.policy` all produce short name `Policy`, prefix
        each colliding variant with preceding NSID segments (`PersonalspacePolicy`,
        `MemberspacePolicy`, `ManagedspacePolicy`).
        """
        short_names = [RustEnumGenerator._short_variant_name(r) for r in normalized_refs]
        counts = Counter(short_names)

        # Depth = number of trailing NSID segments included before the fragment/leaf.
        depths = [0] * len(normalized_refs)
        for i, short in enumerate(short_names):
            if counts[short] > 1 or short in reserved:
                depths[i] = 1

        def build_name(norm_ref: str, depth: int) -> str:
            nsid, sep, fragment = norm_ref.partition("#")
            segments = nsid.split(".")
            if sep:
                base = _segment_pascal(fragment)
                prefix_segs = segments[max(0, len(segments) - depth):] if depth > 0 else []
            else:
                base = _segment_pascal(segments[-1])
                start = max(0, len(segments) - 1 - depth)
                prefix_segs = segments[start:-1] if depth > 0 else []
            candidate = "".join(_segment_pascal(s) for s in prefix_segs) + base
            if not candidate:
                return "Variant"
            return f"V{candidate}" if candidate[0].isdigit() else candidate

        while True:
            candidates = [
                build_name(norm_ref, depths[i]) for i, norm_ref in enumerate(normalized_refs)
            ]
            cand_counts = Counter(candidates)
            changed = False
            for i, cand in enumerate(candidates):
                if cand_counts[cand] > 1 or cand in reserved:
                    nsid, sep, _ = normalized_refs[i].partition("#")
                    max_depth = len(nsid.split(".")) if sep else len(nsid.split(".")) - 1
                    if depths[i] < max_depth:
                        depths[i] += 1
                        changed = True
            if not changed:
                # Final deterministic guarantee against any extreme edge collision.
                used: Set[str] = set(reserved)
                final_names: List[str] = []
                for cand in candidates:
                    name = cand
                    suffix = 2
                    while name in used:
                        name = f"{cand}{suffix}"
                        suffix += 1
                    used.add(name)
                    final_names.append(name)
                return final_names

    def generate_enum_for_union(
        self,
        context_struct_name: str,
        prop_name: str,
        raw_refs: List[str],
        *,
        closed: bool = False,
        union_name: Optional[str] = None,
    ) -> str:
        """Generate a Rust enum for an inline union property."""
        target_name = union_name or f"{context_struct_name}{rust_pascal_case(prop_name)}"
        return self._emit_union(target_name, raw_refs, closed=closed)

    def generate_enum_for_union_def(
        self,
        union_name: str,
        raw_refs: List[str],
        *,
        closed: bool = False,
    ) -> str:
        """Generate a Rust enum for a named top-level union definition."""
        return self._emit_union(union_name, raw_refs, closed=closed)

    def generate_enum_for_union_array(
        self,
        context_struct_name: str,
        prop_name: str,
        raw_refs: List[str],
        *,
        closed: bool = False,
        union_name: Optional[str] = None,
    ) -> str:
        """Generate a Rust enum for an array-of-union item schema."""
        target_name = union_name or f"{context_struct_name}{rust_pascal_case(prop_name)}"
        return self._emit_union(target_name, raw_refs, closed=closed)

    def _emit_union(
        self,
        union_name: str,
        raw_refs: List[str],
        *,
        closed: bool,
    ) -> str:
        if union_name in self.generated_unions:
            return union_name
        self.generated_unions.add(union_name)

        normalized_tags = self._validate_union_refs(union_name, raw_refs, closed=closed)
        reserved = {"Self"} if closed else {"Self", "Unknown"}
        variant_names = self._disambiguate_variant_names(normalized_tags, reserved=reserved)

        variants: List[Dict[str, str]] = []
        for raw_ref, tag, variant_name in zip(raw_refs, normalized_tags, variant_names):
            rust_type = self.code_generator.type_converter.convert_ref(raw_ref)
            variants.append({
                "name": variant_name,
                "type": rust_type,
                "wire_tag": tag,
                "wire_tag_literal": rust_string_literal(tag),
            })

        self.unions[union_name] = {
            "name": union_name,
            "closed": bool(closed),
            "variants": variants,
        }

        lines = [
            "#[derive(Debug, Clone, PartialEq)]",
            f"pub enum {union_name} {{",
        ]
        for variant in variants:
            lines.append(f"    {variant['name']}(Box<{variant['type']}>),")
        if not closed:
            lines.append("    Unknown(petrel_core::Value),")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::ToValue for {union_name} {{")
        lines.append(
            "    fn to_value(&self) -> Result<petrel_core::Value, petrel_core::EncodeError> {"
        )
        lines.append("        match self {")
        for variant in variants:
            lines.append(
                f"            Self::{variant['name']}(member) => petrel_core::unknown::tagged(member.to_value()?, {variant['wire_tag_literal']}),"
            )
        if not closed:
            lines.append("            Self::Unknown(raw) => Ok(raw.clone()),")
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        if variants:
            # One dispatch body for both modes: a member is decoded with the
            # strictness the union itself was decoded with, so an XRPC input
            # stays strict through a union.
            lines.append(f"impl {union_name} {{")
            lines.append(
                "    fn decode_member(value: petrel_core::Value, strict: bool) -> Result<Self, petrel_core::DecodeError> {"
            )
            lines.append("        match petrel_core::unknown::type_of(&value)? {")
            for variant in variants:
                lines.append(
                    f"            {variant['wire_tag_literal']} => petrel_core::decode_value(value, strict).map(Self::{variant['name']}),"
                )
            if not closed:
                lines.append("            _ => Ok(Self::Unknown(value)),")
            else:
                lines.append(
                    "            other => Err(petrel_core::DecodeError::UnknownType(other.to_owned())),"
                )
            lines.append("        }")
            lines.append("    }")
            lines.append("}")
            lines.append("")
        lines.append(f"impl petrel_core::FromValue for {union_name} {{")
        lines.append(
            "    fn from_value(value: petrel_core::Value) -> Result<Self, petrel_core::DecodeError> {"
        )
        if variants:
            lines.append("        Self::decode_member(value, false)")
            lines.append("    }")
            lines.append("")
            lines.append(
                "    fn from_value_strict(value: petrel_core::Value) -> Result<Self, petrel_core::DecodeError> {"
            )
            lines.append("        Self::decode_member(value, true)")
        else:
            lines.append("        let _ = petrel_core::unknown::type_of(&value)?;")
            lines.append("        Ok(Self::Unknown(value))")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::XrpcInput for {union_name} {{")
        lines.append(
            "    fn into_body(self) -> Result<Option<Vec<u8>>, petrel_core::EncodeError> {"
        )
        lines.append("        petrel_core::xrpc::json_body(&self)")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::XrpcOutput for {union_name} {{")
        lines.append(
            "    fn from_body(body: &[u8]) -> Result<Self, petrel_core::DecodeError> {"
        )
        lines.append("        petrel_core::from_json(body)")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl serde::Serialize for {union_name} {{")
        lines.append(
            "    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {"
        )
        lines.append("        petrel_core::serde_bridge::serialize(self, serializer)")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl<'de> serde::Deserialize<'de> for {union_name} {{")
        lines.append(
            "    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {"
        )
        lines.append("        petrel_core::serde_bridge::deserialize(deserializer)")
        lines.append("    }")
        lines.append("}")
        rendered = "\n".join(lines)
        self.enums_code.append(rendered)
        return union_name

    def generate_enum_from_known_values(
        self,
        enum_name: str,
        known_values: List[str],
        descriptions: Optional[Dict[str, str]] = None,
    ) -> str:
        """Generate an open enum with `Other(String)` for a named `knownValues` definition."""
        if enum_name in self.generated_known_values:
            return enum_name
        if not isinstance(known_values, list) or not all(isinstance(v, str) for v in known_values):
            raise ValueError(f"knownValues enum '{enum_name}' values must be a list of strings")

        self.generated_known_values.add(enum_name)

        used_variants: Set[str] = set()
        seen_wire: Set[str] = set()
        entries: List[Dict[str, str]] = []
        for value in known_values:
            if value in seen_wire:
                continue
            seen_wire.add(value)
            variant_name = _clean_variant_identifier(
                value, used_variants, reserved={"Self", "Other"}
            )
            entries.append({
                "name": variant_name,
                "wire_value": value,
                "wire_literal": rust_string_literal(value),
                "description": (descriptions or {}).get(value, ""),
            })

        lines: List[str] = [
            "#[derive(Debug, Clone, PartialEq, Eq, Hash)]",
            f"pub enum {enum_name} {{",
        ]
        for entry in entries:
            lines.append(f"    {entry['name']},")
        lines.append("    Other(String),")
        lines.append("}")
        lines.append("")
        lines.append(f"impl {enum_name} {{")
        lines.append("    pub fn as_str(&self) -> &str {")
        lines.append("        match self {")
        for entry in entries:
            lines.append(f"            Self::{entry['name']} => {entry['wire_literal']},")
        lines.append("            Self::Other(value) => value.as_str(),")
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl core::fmt::Display for {enum_name} {{")
        lines.append("    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {")
        lines.append("        f.write_str(self.as_str())")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl core::str::FromStr for {enum_name} {{")
        lines.append("    type Err = core::convert::Infallible;")
        lines.append("    fn from_str(s: &str) -> Result<Self, Self::Err> {")
        lines.append("        Ok(match s {")
        for entry in entries:
            lines.append(f"            {entry['wire_literal']} => Self::{entry['name']},")
        lines.append("            other => Self::Other(other.to_owned()),")
        lines.append("        })")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl From<&str> for {enum_name} {{")
        lines.append("    fn from(s: &str) -> Self {")
        lines.append("        match s {")
        for entry in entries:
            lines.append(f"            {entry['wire_literal']} => Self::{entry['name']},")
        lines.append("            other => Self::Other(other.to_owned()),")
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl From<String> for {enum_name} {{")
        lines.append("    fn from(s: String) -> Self {")
        lines.append("        match s.as_str() {")
        for entry in entries:
            lines.append(f"            {entry['wire_literal']} => Self::{entry['name']},")
        lines.append("            _ => Self::Other(s),")
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::ToValue for {enum_name} {{")
        lines.append(
            "    fn to_value(&self) -> Result<petrel_core::Value, petrel_core::EncodeError> {"
        )
        lines.append("        Ok(petrel_core::Value::String(self.as_str().to_owned()))")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::FromValue for {enum_name} {{")
        lines.append(
            "    fn from_value(value: petrel_core::Value) -> Result<Self, petrel_core::DecodeError> {"
        )
        lines.append("        Ok(Self::from(String::from_value(value)?))")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::xrpc::QueryValue for {enum_name} {{")
        lines.append("    fn to_query_value(&self) -> String {")
        lines.append("        self.as_str().to_owned()")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::XrpcInput for {enum_name} {{")
        lines.append(
            "    fn into_body(self) -> Result<Option<Vec<u8>>, petrel_core::EncodeError> {"
        )
        lines.append("        petrel_core::xrpc::json_body(&self)")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::XrpcOutput for {enum_name} {{")
        lines.append(
            "    fn from_body(body: &[u8]) -> Result<Self, petrel_core::DecodeError> {"
        )
        lines.append("        petrel_core::from_json(body)")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl serde::Serialize for {enum_name} {{")
        lines.append(
            "    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {"
        )
        lines.append("        petrel_core::serde_bridge::serialize(self, serializer)")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl<'de> serde::Deserialize<'de> for {enum_name} {{")
        lines.append(
            "    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {"
        )
        lines.append("        petrel_core::serde_bridge::deserialize(deserializer)")
        lines.append("    }")
        lines.append("}")

        rendered = "\n".join(lines)
        self.known_values_enums[enum_name] = rendered
        self.enums_code.append(rendered)
        return enum_name

    def generate_closed_string_enum(
        self,
        enum_name: str,
        values: List[str],
        identity: Any,
    ) -> str:
        """Generate a closed Rust enum with collision-detecting identity registry."""
        if not isinstance(values, list) or not all(isinstance(v, str) for v in values):
            raise ValueError(f"closed enum '{enum_name}' values must be a list of strings")
        if len(values) != len(set(values)):
            raise ValueError(f"closed enum '{enum_name}' contains duplicate wire values")

        vocabulary = tuple(values)
        existing = self.closed_enums_by_identity.get(identity)
        if existing is not None:
            existing_name, existing_vocabulary = existing
            if existing_name != enum_name or existing_vocabulary != vocabulary:
                raise ValueError(
                    f"closed enum identity {identity!r} was reused with a different schema"
                )
            return existing_name

        owner = self.closed_enum_identity_by_name.get(enum_name)
        if owner is not None and owner != identity:
            raise ValueError(
                f"closed enum type name collision for '{enum_name}': {owner!r} vs {identity!r}"
            )

        used_variants: Set[str] = set()
        entries: List[Dict[str, str]] = []
        for value in values:
            variant_name = _clean_variant_identifier(value, used_variants)
            entries.append({
                "name": variant_name,
                "wire_literal": rust_string_literal(value),
            })

        expected_variants = ", ".join(entry["wire_literal"] for entry in entries)
        lines: List[str] = [
            "#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]",
            f"pub enum {enum_name} {{",
        ]
        for entry in entries:
            lines.append(f"    {entry['name']},")
        lines.append("}")
        lines.append("")
        lines.append(f"impl {enum_name} {{")
        lines.append("    pub const fn as_str(&self) -> &'static str {")
        lines.append("        match self {")
        for entry in entries:
            lines.append(f"            Self::{entry['name']} => {entry['wire_literal']},")
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl core::fmt::Display for {enum_name} {{")
        lines.append("    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {")
        lines.append("        f.write_str(self.as_str())")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl core::str::FromStr for {enum_name} {{")
        lines.append("    type Err = &'static str;")
        lines.append("    fn from_str(s: &str) -> Result<Self, Self::Err> {")
        lines.append("        match s {")
        for entry in entries:
            lines.append(f"            {entry['wire_literal']} => Ok(Self::{entry['name']}),")
        lines.append(f'            _ => Err("unknown variant for {enum_name}"),')
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::ToValue for {enum_name} {{")
        lines.append(
            "    fn to_value(&self) -> Result<petrel_core::Value, petrel_core::EncodeError> {"
        )
        lines.append("        Ok(petrel_core::Value::String(self.as_str().to_owned()))")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::FromValue for {enum_name} {{")
        lines.append(
            "    fn from_value(value: petrel_core::Value) -> Result<Self, petrel_core::DecodeError> {"
        )
        lines.append("        let raw = String::from_value(value)?;")
        lines.append("        match raw.as_str() {")
        for entry in entries:
            lines.append(f"            {entry['wire_literal']} => Ok(Self::{entry['name']}),")
        lines.append(
            f'            other => Err(petrel_core::DecodeError::Custom(format!("unknown variant `{{other}}` for {enum_name}"))),'
        )
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::xrpc::QueryValue for {enum_name} {{")
        lines.append("    fn to_query_value(&self) -> String {")
        lines.append("        self.as_str().to_owned()")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::XrpcInput for {enum_name} {{")
        lines.append(
            "    fn into_body(self) -> Result<Option<Vec<u8>>, petrel_core::EncodeError> {"
        )
        lines.append("        petrel_core::xrpc::json_body(&self)")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl petrel_core::XrpcOutput for {enum_name} {{")
        lines.append(
            "    fn from_body(body: &[u8]) -> Result<Self, petrel_core::DecodeError> {"
        )
        lines.append("        petrel_core::from_json(body)")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl serde::Serialize for {enum_name} {{")
        lines.append(
            "    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {"
        )
        lines.append("        petrel_core::serde_bridge::serialize(self, serializer)")
        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append(f"impl<'de> serde::Deserialize<'de> for {enum_name} {{")
        lines.append(
            "    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {"
        )
        lines.append("        petrel_core::serde_bridge::deserialize(deserializer)")
        lines.append("    }")
        lines.append("}")

        rendered = "\n".join(lines)
        self.closed_enums[enum_name] = rendered
        self.closed_enums_by_identity[identity] = (enum_name, vocabulary)
        self.closed_enum_identity_by_name[enum_name] = identity
        self.enums_code.append(rendered)
        return enum_name
