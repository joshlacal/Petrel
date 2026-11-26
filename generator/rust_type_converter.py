"""
Rust type converter and naming/cycle helpers for AT Protocol Lexicons.
"""
from __future__ import annotations

import re
from typing import Any, Dict, FrozenSet, List, Optional, Set, Tuple

from base_code_generator import BaseTypeConverter

# Rust 2024 strict & reserved keywords that can be escaped with `r#<kw>`.
RUST_RAWABLE_KEYWORDS: FrozenSet[str] = frozenset({
    "abstract",
    "as",
    "async",
    "await",
    "become",
    "box",
    "break",
    "const",
    "continue",
    "do",
    "dyn",
    "else",
    "enum",
    "extern",
    "false",
    "final",
    "fn",
    "for",
    "gen",
    "if",
    "impl",
    "in",
    "let",
    "loop",
    "macro",
    "match",
    "mod",
    "move",
    "mut",
    "override",
    "priv",
    "pub",
    "ref",
    "return",
    "static",
    "struct",
    "trait",
    "true",
    "try",
    "type",
    "typeof",
    "unsafe",
    "unsized",
    "use",
    "virtual",
    "where",
    "while",
    "yield",
})

# Path/self keywords that CANNOT use `r#` in Rust and must be suffixed.
RUST_NON_RAWABLE_KEYWORDS: FrozenSet[str] = frozenset({
    "self",
    "Self",
    "super",
    "crate",
})

_NON_ALNUM_RE = re.compile(r"[^A-Za-z0-9]+")
_CAMEL_BOUNDARY_1 = re.compile(r"([A-Z]+)([A-Z][a-z])")
_CAMEL_BOUNDARY_2 = re.compile(r"([a-z0-9])([A-Z])")

_STRING_FORMAT_MAP: Dict[str, str] = {
    "did": "petrel_core::Did",
    "handle": "petrel_core::Handle",
    "at-identifier": "petrel_core::AtIdentifier",
    "nsid": "petrel_core::Nsid",
    "at-uri": "petrel_core::AtUri",
    "space-ref": "petrel_core::SpaceRef",
    "uri": "petrel_core::Uri",
    "tid": "petrel_core::Tid",
    "record-key": "petrel_core::RecordKey",
    "datetime": "petrel_core::Datetime",
    "language": "petrel_core::Language",
    "cid": "petrel_core::CidString",
}

_PRIMARY_HELPER_TYPE_NAMES: FrozenSet[str] = frozenset({
    "Parameters",
    "Input",
    "Output",
    "Message",
    "Error",
})


def rust_pascal_case(value: str) -> str:
    """Convert an identifier, NSID segment, or def name to Rust PascalCase."""
    parts = [part for part in _NON_ALNUM_RE.split(value) if part]
    if not parts:
        return "_"
    camel = "".join(part[0].upper() + part[1:] for part in parts)
    if camel[0].isdigit():
        camel = f"_{camel}"
    if camel == "Self":
        return "Self_"
    return camel


def rust_snake_case(value: str) -> str:
    """Convert camelCase, PascalCase, or hyphenated wire names to snake_case."""
    if not value:
        return "_"
    parts = [part for part in _NON_ALNUM_RE.split(value.replace("$", "_")) if part]
    if not parts:
        return "_"
    snake_parts: List[str] = []
    for part in parts:
        s1 = _CAMEL_BOUNDARY_1.sub(r"\1_\2", part)
        s2 = _CAMEL_BOUNDARY_2.sub(r"\1_\2", s1)
        snake_parts.append(s2.lower())
    snake = "_".join(snake_parts)
    if not snake:
        return "_"
    if snake[0].isdigit():
        snake = f"_{snake}"
    return snake


def sanitize_rust_ident(ident: str) -> str:
    """Escape a Rust identifier using `r#` for rawable keywords or `_` suffix for non-rawable."""
    if not ident:
        return "_"
    if ident in RUST_NON_RAWABLE_KEYWORDS:
        return f"{ident}_"
    if ident in RUST_RAWABLE_KEYWORDS:
        return f"r#{ident}"
    return ident


def rust_field_ident(wire_name: str, used_idents: Optional[Set[str]] = None) -> str:
    """Map a Lexicon property wire name to a collision-free Rust field identifier."""
    base = rust_snake_case(wire_name)
    if used_idents is None:
        return sanitize_rust_ident(base)
    candidate = base
    while sanitize_rust_ident(candidate) in used_idents:
        candidate += "_"
    ident = sanitize_rust_ident(candidate)
    used_idents.add(ident)
    return ident


def rust_module_ident(segment: str) -> str:
    """Convert one NSID segment into a valid Rust module identifier."""
    return sanitize_rust_ident(rust_snake_case(segment))


def rust_module_file_stem(segment: str) -> str:
    """Convert one NSID segment into its filesystem module stem (stripping `r#`)."""
    return rust_module_ident(segment).removeprefix("r#")


def rust_module_segments(lexicon_id: str) -> List[str]:
    """Return all Rust module segments for a lexicon NSID."""
    return [rust_module_ident(seg) for seg in lexicon_id.split(".")]


def rust_module_file_segments(lexicon_id: str) -> List[str]:
    """Return filesystem module path segments (without `r#`) for a lexicon NSID."""
    return [rust_module_file_stem(seg) for seg in lexicon_id.split(".")]


def rust_module_path(lexicon_id: str) -> str:
    """Return the `::`-joined module path for a lexicon NSID."""
    return "::".join(rust_module_segments(lexicon_id))


def _reserved_names_for_main(lexicon_id: str, main_def: Optional[Dict[str, Any]]) -> Set[str]:
    reserved: Set[str] = set()
    if not isinstance(main_def, dict):
        return reserved
    main_type = main_def.get("type")
    if main_type and main_type != "token":
        reserved.add(rust_pascal_case(lexicon_id.rsplit(".", 1)[-1]))
    if main_type in ("query", "procedure", "subscription"):
        reserved.update(_PRIMARY_HELPER_TYPE_NAMES)
    return reserved


def _extract_module_defs_from_registry(
    lexicon_id: str,
    registry: Optional[Dict[str, Dict[str, Any]]],
) -> Optional[Dict[str, Any]]:
    if registry is None:
        return None
    prefix = f"{lexicon_id}#"
    defs: Dict[str, Any] = {}
    if lexicon_id in registry:
        defs["main"] = registry[lexicon_id]
    for key, schema in registry.items():
        if key.startswith(prefix):
            defs[key[len(prefix):]] = schema
    return defs or None


def _resolve_module_def_names(lexicon_id: str, defs: Dict[str, Any]) -> Dict[str, str]:
    main_def = defs.get("main")
    reserved = _reserved_names_for_main(lexicon_id, main_def)
    mapping: Dict[str, str] = {}
    if "main" in defs:
        mapping["main"] = rust_pascal_case(lexicon_id.rsplit(".", 1)[-1])

    non_token_defs = [
        def_name
        for def_name, def_schema in defs.items()
        if def_name != "main"
        and not (isinstance(def_schema, dict) and def_schema.get("type") == "token")
    ]

    taken: Set[str] = set(reserved)
    deferred: List[str] = []
    for def_name in non_token_defs:
        base_name = rust_pascal_case(def_name)
        if base_name not in taken:
            taken.add(base_name)
            mapping[def_name] = base_name
        else:
            deferred.append(def_name)

    for def_name in deferred:
        base_name = rust_pascal_case(def_name)
        candidate = f"{base_name}Def"
        suffix = 2
        while candidate in taken:
            candidate = f"{base_name}Def{suffix}"
            suffix += 1
        taken.add(candidate)
        mapping[def_name] = candidate

    return mapping


def resolve_rust_def_type_name(
    lexicon_id: str,
    def_name: str,
    *,
    lexicon_defs: Optional[Dict[str, Any]] = None,
    registry: Optional[Dict[str, Dict[str, Any]]] = None,
) -> str:
    """Resolve the Rust type name for a definition inside its lexicon module.

    `main` always maps to `PascalCase(last_nsid_segment)`.
    Non-main defs map to `PascalCase(def_name)`, disambiguated with a `Def` suffix
    if they collide with `main` (e.g. `app.bsky.embed.external#external` -> `ExternalDef`),
    endpoint helper types (`Parameters`/`Input`/`Output`/`Message`/`Error`), or another
    definition in the same module (e.g. `externalDef` keeps `ExternalDef` while
    colliding `external` becomes `ExternalDef2`). Both same-module and cross-module
    callers consult the full module def set via `lexicon_defs` or `registry` so they
    always agree.
    """
    if def_name == "main":
        return rust_pascal_case(lexicon_id.rsplit(".", 1)[-1])

    defs = lexicon_defs if isinstance(lexicon_defs, dict) else _extract_module_defs_from_registry(
        lexicon_id, registry
    )
    if isinstance(defs, dict):
        mapping = _resolve_module_def_names(lexicon_id, defs)
        if def_name in mapping:
            return mapping[def_name]

    base_name = rust_pascal_case(def_name)
    main_def = registry.get(lexicon_id) if registry is not None else None
    reserved = _reserved_names_for_main(lexicon_id, main_def)
    if base_name not in reserved:
        return base_name
    return f"{base_name}Def"


def is_schemaless_json_body(body_obj: Optional[Dict[str, Any]]) -> bool:
    """True when an XRPC input/output has `application/json` encoding and no schema.

    Natively ports `mls-ds/codegen`'s `patch_schemaless_json_outputs` (e.g. `labyrinthRelay`):
    a schemaless JSON body must decode/encode as raw `petrel_core::Bytes` rather than `()`.
    """
    if not isinstance(body_obj, dict):
        return False
    encoding = body_obj.get("encoding", "")
    return encoding == "application/json" and "schema" not in body_obj


def is_raw_bytes_schema(schema_obj: Optional[Dict[str, Any]]) -> bool:
    """True when an XRPC input/output schema is bare `{ "type": "bytes" }`."""
    return isinstance(schema_obj, dict) and schema_obj.get("type") == "bytes"


def _resolve_target_schema(
    ref: str,
    current_lexicon_id: str,
    current_defs: Dict[str, Any],
    registry: Optional[Dict[str, Dict[str, Any]]],
) -> Tuple[str, str, Optional[Dict[str, Any]]]:
    """Return `(target_nsid, target_def, target_schema)` for a ref string."""
    nsid, separator, fragment = ref.partition("#")
    target_nsid = nsid or current_lexicon_id
    target_def = fragment if (separator and fragment) else "main"

    if target_nsid == current_lexicon_id:
        schema = current_defs.get(target_def)
    elif registry is not None:
        key = target_nsid if target_def == "main" else f"{target_nsid}#{target_def}"
        schema = registry.get(key)
    else:
        schema = None
    return target_nsid, target_def, schema


def _collect_direct_ref_edges(
    schema: Any,
    owner_nsid: str,
    owner_defs: Dict[str, Any],
    registry: Optional[Dict[str, Dict[str, Any]]],
    *,
    through_heap: bool = False,
) -> List[Tuple[str, str, bool]]:
    """Collect `(target_node_key, prop_name, is_optional)` for size-relevant edges.

    Arrays (`Vec<T>`), schemaless objects (`BTreeMap`), and unions (all variants `Box<T>`)
    allocate on the heap and break Rust struct-size recursion. Direct refs, `Option<T>`,
    `Nullable<T>`, and inline objects with properties carry size edges.
    """
    edges: List[Tuple[str, str, bool]] = []
    if not isinstance(schema, dict):
        return edges

    schema_type = schema.get("type")
    if schema_type == "record":
        obj = schema.get("record")
        return _collect_direct_ref_edges(
            obj, owner_nsid, owner_defs, registry, through_heap=through_heap
        )

    if schema_type != "object":
        return edges

    props = schema.get("properties")
    if not isinstance(props, dict) or not props:
        return edges

    required = set(schema.get("required") or [])

    def visit_prop(prop_name: str, prop_schema: Any, is_opt: bool, heap_broken: bool) -> None:
        if not isinstance(prop_schema, dict) or heap_broken:
            return
        pt = prop_schema.get("type")
        if pt == "ref":
            ref_str = prop_schema.get("ref", "")
            t_nsid, t_def, t_schema = _resolve_target_schema(
                ref_str, owner_nsid, owner_defs, registry
            )
            if isinstance(t_schema, dict) and t_schema.get("type") in ("object", "record"):
                target_key = t_nsid if t_def == "main" else f"{t_nsid}#{t_def}"
                edges.append((target_key, prop_name, is_opt))
        elif pt == "object" and isinstance(prop_schema.get("properties"), dict) and prop_schema["properties"]:
            # Inline objects are structs in the same module; walk their properties
            # attributing edges to the enclosing property for cycle detection.
            inline_req = set(prop_schema.get("required") or [])
            for sub_name, sub_schema in prop_schema["properties"].items():
                visit_prop(prop_name, sub_schema, is_opt or (sub_name not in inline_req), False)

    for prop_name, prop_schema in props.items():
        visit_prop(prop_name, prop_schema, prop_name not in required, through_heap)
    return edges


def compute_rust_boxed_fields(
    schemas_by_ref: Dict[str, Dict[str, Any]],
) -> Set[Tuple[str, str]]:
    """Compute `(ref_key, prop_name)` pairs that must be `Box<T>` to break Rust struct-size cycles.

    Uses Tarjan's SCC over object/record nodes connected by non-heap-indirected ref edges.
    Prefers boxing optional fields over required fields inside each cycle.
    """
    # Group defs by lexicon ID for local resolution.
    defs_by_nsid: Dict[str, Dict[str, Any]] = {}
    for ref_key, schema in schemas_by_ref.items():
        nsid, sep, frag = ref_key.partition("#")
        dname = frag if sep else "main"
        defs_by_nsid.setdefault(nsid, {})[dname] = schema

    adj: Dict[str, List[Tuple[str, str, bool]]] = {}
    for ref_key in sorted(schemas_by_ref):
        schema = schemas_by_ref[ref_key]
        if not isinstance(schema, dict) or schema.get("type") not in ("object", "record"):
            continue
        nsid, _, _ = ref_key.partition("#")
        edges = _collect_direct_ref_edges(
            schema, nsid, defs_by_nsid.get(nsid, {}), schemas_by_ref
        )
        if edges:
            adj[ref_key] = edges

    boxed: Set[Tuple[str, str]] = set()
    removed_edges: Set[Tuple[str, str, str]] = set()

    while True:
        # Find SCCs on remaining edges via Tarjan's algorithm.
        index_counter = 0
        indices: Dict[str, int] = {}
        lowlink: Dict[str, int] = {}
        stack: List[str] = []
        on_stack: Set[str] = set()
        sccs: List[List[str]] = []

        def strongconnect(node: str) -> None:
            nonlocal index_counter
            indices[node] = index_counter
            lowlink[node] = index_counter
            index_counter += 1
            stack.append(node)
            on_stack.add(node)

            for target, prop_name, _ in adj.get(node, ()):
                if (node, prop_name, target) in removed_edges or target not in adj:
                    continue
                if target not in indices:
                    strongconnect(target)
                    lowlink[node] = min(lowlink[node], lowlink[target])
                elif target in on_stack:
                    lowlink[node] = min(lowlink[node], indices[target])

            if lowlink[node] == indices[node]:
                comp: List[str] = []
                while True:
                    w = stack.pop()
                    on_stack.remove(w)
                    comp.append(w)
                    if w == node:
                        break
                sccs.append(comp)

        for node in sorted(adj):
            if node not in indices:
                strongconnect(node)

        cyclic_edges: List[Tuple[int, str, str, str]] = []
        for comp in sccs:
            comp_set = set(comp)
            for src in comp:
                for target, prop_name, is_opt in adj.get(src, ()):
                    if (src, prop_name, target) in removed_edges:
                        continue
                    if target in comp_set:
                        # Self-loop or edge within an SCC of size >= 1.
                        if len(comp) > 1 or target == src:
                            # Priority 0 = optional (preferred), 1 = required
                            cyclic_edges.append((0 if is_opt else 1, src, prop_name, target))

        if not cyclic_edges:
            break

        cyclic_edges.sort()
        _, chosen_src, chosen_prop, chosen_target = cyclic_edges[0]
        boxed.add((chosen_src, chosen_prop))
        # Remove all edges for that property on chosen_src (it's now Box<T>).
        for target, prop_name, _ in adj.get(chosen_src, ()):
            if prop_name == chosen_prop:
                removed_edges.add((chosen_src, chosen_prop, target))

    return boxed


class RustTypeConverter(BaseTypeConverter):
    """Converts AT Protocol Lexicon schemas to Rust types."""

    def __init__(
        self,
        code_generator,
        *,
        emit_ids: Optional[Set[str]] = None,
        crate_path: str = "crate",
        reference_crate: str = "petrel_api",
        property_type_overrides: Optional[Dict[str, str]] = None,
        boxed_fields: Optional[Set[Tuple[str, str]]] = None,
    ):
        super().__init__(code_generator)
        self.emit_ids = set(emit_ids) if emit_ids is not None else None
        self.crate_path = crate_path
        self.reference_crate = reference_crate
        self.property_type_overrides = dict(property_type_overrides or {})
        self.used_property_type_overrides: Set[str] = set()
        self._boxed_fields = boxed_fields

    def _get_boxed_fields(self) -> Set[Tuple[str, str]]:
        if self._boxed_fields is not None:
            return self._boxed_fields
        registry = getattr(self.code_generator.cycle_detector, "schemas_by_ref", None)
        if registry:
            self._boxed_fields = compute_rust_boxed_fields(registry)
        else:
            # Standalone single-lexicon fallback (e.g. unit tests without CycleDetector).
            local_schemas: Dict[str, Dict[str, Any]] = {}
            lex_id = self.code_generator.lexicon_id
            for dname, dschema in self.code_generator.defs.items():
                key = lex_id if dname == "main" else f"{lex_id}#{dname}"
                local_schemas[key] = dschema
            self._boxed_fields = compute_rust_boxed_fields(local_schemas)
        return self._boxed_fields

    def should_box_property(
        self,
        prop_name: str,
        *,
        def_name: Optional[str] = None,
        current_struct_name: Optional[str] = None,
    ) -> bool:
        """Return True when a property must be wrapped in `Box<T>` to break a struct-size cycle."""
        lex_id = self.code_generator.lexicon_id
        boxed = self._get_boxed_fields()
        if def_name is not None:
            key = lex_id if def_name == "main" else f"{lex_id}#{def_name}"
            if (key, prop_name) in boxed:
                return True
        if current_struct_name is not None:
            # Match main or matching def by PascalCase name when def_name wasn't passed explicitly.
            for dname in self.code_generator.defs:
                resolved = resolve_rust_def_type_name(
                    lex_id,
                    dname,
                    lexicon_defs=self.code_generator.defs,
                )
                if resolved == current_struct_name:
                    key = lex_id if dname == "main" else f"{lex_id}#{dname}"
                    if (key, prop_name) in boxed:
                        return True
        return False

    def assert_all_overrides_used(self) -> None:
        unused = sorted(set(self.property_type_overrides) - self.used_property_type_overrides)
        if unused:
            raise ValueError(
                f"{self.code_generator.lexicon_id}: rust.property_type_overrides "
                f"match no generated property: {unused}"
            )

    def determine_type(
        self,
        name: str,
        prop_schema: Dict[str, Any],
        required_fields: List[str],
        current_struct_name: str,
        *,
        context_identity=None,
        nullable_fields: Optional[List[str]] = None,
        tri_state_nullable: bool = True,
        def_name: Optional[str] = None,
    ) -> str:
        """Determine the full Rust type for a Lexicon property (including Option/Nullable/Box)."""
        base_type = self._get_base_type(
            prop_schema,
            name,
            current_struct_name,
            context_identity=context_identity,
        )

        override_key = f"{current_struct_name}.{name}"
        if override_key in self.property_type_overrides:
            base_type = self.property_type_overrides[override_key]
            self.used_property_type_overrides.add(override_key)

        if self.should_box_property(
            name, def_name=def_name, current_struct_name=current_struct_name
        ):
            base_type = f"Box<{base_type}>"

        is_optional = name not in required_fields
        is_nullable = name in (nullable_fields or [])

        if is_optional and is_nullable:
            if tri_state_nullable:
                return f"Option<petrel_core::Nullable<{base_type}>>"
            return f"Option<{base_type}>"
        if not is_optional and is_nullable:
            # Required-nullable fields are Option<T> with ObjectReader::required_nullable
            # / ObjectWriter::required_nullable (key always present on wire).
            return f"Option<{base_type}>"
        if is_optional:
            return f"Option<{base_type}>"
        return base_type

    def _get_base_type(
        self,
        prop_schema: Dict[str, Any],
        name: str,
        current_struct_name: str,
        *,
        context_identity=None,
    ) -> str:
        prop_type = prop_schema.get("type")
        format_type = prop_schema.get("format")

        if prop_type == "string":
            if "enum" in prop_schema:
                enum_name = f"{current_struct_name}{rust_pascal_case(name)}"
                identity = (
                    "inline",
                    self.code_generator.lexicon_id,
                    context_identity if context_identity is not None else ("rendered", current_struct_name),
                    name,
                )
                enum_gen = getattr(self.code_generator, "enum_generator", None)
                if enum_gen is not None:
                    enum_gen.generate_closed_string_enum(
                        enum_name, prop_schema["enum"], identity
                    )
                return enum_name
            # Inline `knownValues` stays `String` (Plan §Lane B).
            return self._convert_string_type(format_type)
        if prop_type == "integer":
            return "i64"
        if prop_type == "boolean":
            return "bool"
        if prop_type == "bytes":
            return "petrel_core::Bytes"
        if prop_type == "cid-link":
            return "petrel_core::CidLink"
        if prop_type == "blob":
            return "petrel_core::Blob"
        if prop_type == "unknown":
            return "petrel_core::Value"
        if prop_type == "ref":
            return self.convert_ref(prop_schema["ref"])
        if prop_type == "array":
            item_type = self._get_array_item_type(
                prop_schema,
                name,
                current_struct_name,
                context_identity=context_identity,
            )
            return f"Vec<{item_type}>"
        if prop_type == "union":
            union_name = f"{current_struct_name}{rust_pascal_case(name)}"
            unclaimed = getattr(self.code_generator, "unclaimed_inline_type_name", None)
            if callable(unclaimed):
                union_name = unclaimed(union_name, suffix="Union")
            enum_gen = getattr(self.code_generator, "enum_generator", None)
            if enum_gen is not None:
                enum_gen.generate_enum_for_union(
                    current_struct_name,
                    name,
                    prop_schema.get("refs", []),
                    closed=bool(prop_schema.get("closed", False)),
                    union_name=union_name,
                )
            return union_name
        if prop_type == "object":
            props = prop_schema.get("properties")
            if isinstance(props, dict) and props:
                inline_gen = getattr(self.code_generator, "generate_inline_object", None)
                if callable(inline_gen):
                    return inline_gen(current_struct_name, name, prop_schema, context_identity)
                return f"{current_struct_name}{rust_pascal_case(name)}"
            return "std::collections::BTreeMap<String, petrel_core::Value>"

        raise ValueError(
            f"{self.code_generator.lexicon_id}: property '{name}' has type {prop_type!r}, "
            "which is not a Lexicon field type"
        )

    def _get_array_item_type(
        self,
        prop_schema: Dict[str, Any],
        name: str,
        current_struct_name: str,
        *,
        context_identity=None,
    ) -> str:
        items_schema = prop_schema.get("items")
        if not isinstance(items_schema, dict):
            raise ValueError(
                f"{self.code_generator.lexicon_id}: array property '{name}' has invalid items schema"
            )
        items_type = items_schema.get("type")
        if items_type == "union":
            union_name = f"{current_struct_name}{rust_pascal_case(name)}"
            unclaimed = getattr(self.code_generator, "unclaimed_inline_type_name", None)
            if callable(unclaimed):
                union_name = unclaimed(union_name, suffix="Union")
            enum_gen = getattr(self.code_generator, "enum_generator", None)
            if enum_gen is not None:
                enum_gen.generate_enum_for_union_array(
                    current_struct_name,
                    name,
                    items_schema.get("refs", []),
                    closed=bool(items_schema.get("closed", False)),
                    union_name=union_name,
                )
            return union_name

        return self._get_base_type(
            items_schema,
            name,
            current_struct_name,
            context_identity=context_identity,
        )

    @staticmethod
    def _convert_string_type(format_type: Optional[str]) -> str:
        if not format_type:
            return "String"
        return _STRING_FORMAT_MAP.get(format_type, "String")

    def convert_primitive(self, type_name: str, format_name: Optional[str] = None) -> str:
        """Convert primitive types."""
        if type_name == "string":
            return self._convert_string_type(format_name)
        if type_name == "integer":
            return "i64"
        if type_name == "boolean":
            return "bool"
        if type_name == "bytes":
            return "petrel_core::Bytes"
        if type_name == "cid-link":
            return "petrel_core::CidLink"
        if type_name == "blob":
            return "petrel_core::Blob"
        if type_name == "unknown":
            return "petrel_core::Value"
        raise ValueError(
            f"{self.code_generator.lexicon_id}: unsupported primitive lexicon type {type_name!r}"
        )

    def convert_ref(self, ref: str) -> str:
        """Resolve a Lexicon ref to its Rust type path or inlined primitive type."""
        registry = getattr(self.code_generator.cycle_detector, "schemas_by_ref", None)
        target_nsid, target_def, target_schema = _resolve_target_schema(
            ref,
            self.code_generator.lexicon_id,
            self.code_generator.defs,
            registry,
        )

        if isinstance(target_schema, dict):
            target_type = target_schema.get("type")
            # Natively inline named bytes/blob/cid-link refs (ports mls-ds inline_bytes_alias_refs).
            if target_type == "bytes":
                return "petrel_core::Bytes"
            if target_type == "blob":
                return "petrel_core::Blob"
            if target_type == "cid-link":
                return "petrel_core::CidLink"

        local_defs = (
            self.code_generator.defs
            if target_nsid == self.code_generator.lexicon_id
            else None
        )
        type_name = resolve_rust_def_type_name(
            target_nsid,
            target_def,
            lexicon_defs=local_defs,
            registry=registry,
        )

        if target_nsid == self.code_generator.lexicon_id:
            return type_name

        ns_path = rust_module_path(target_nsid)
        if self.emit_ids is None or target_nsid in self.emit_ids:
            return f"{self.crate_path}::{ns_path}::{type_name}"
        return f"{self.reference_crate}::{ns_path}::{type_name}"
