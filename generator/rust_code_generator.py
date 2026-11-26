"""
Rust code generator - generates Rust modules from AT Protocol Lexicons.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional, Set, Tuple

from base_code_generator import BaseCodeGenerator
from rust_enum_generator import RustEnumGenerator, rust_string_literal
from rust_templates import RustTemplateManager
from rust_type_converter import (
    RustTypeConverter,
    is_raw_bytes_schema,
    is_schemaless_json_body,
    resolve_rust_def_type_name,
    rust_field_ident,
    rust_pascal_case,
    rust_snake_case,
)

_EXTRA_DATA_CANDIDATES = ("extra_data", "undeclared_fields", "_extra_data")
_PRIMARY_HELPER_NAMES = frozenset({"Parameters", "Input", "Output", "Message", "Error"})


class RustCodeGenerator(BaseCodeGenerator):
    """Generates deterministic Rust source code for one AT Protocol Lexicon."""

    def __init__(
        self,
        lexicon: Dict[str, Any],
        cycle_detector=None,
        *,
        emit_ids: Optional[Set[str]] = None,
        crate_path: str = "crate",
        reference_crate: str = "petrel_api",
        overlay: bool = False,
        property_type_overrides: Optional[Dict[str, str]] = None,
        boxed_fields: Optional[Set[Tuple[str, str]]] = None,
    ):
        self.overlay = overlay
        super().__init__(lexicon, cycle_detector)

        self.main_name = resolve_rust_def_type_name(
            self.lexicon_id,
            "main",
            lexicon_defs=self.defs,
        )
        self.template_manager = RustTemplateManager()
        self.type_converter = RustTypeConverter(
            self,
            emit_ids=emit_ids,
            crate_path=crate_path,
            reference_crate=reference_crate,
            property_type_overrides=property_type_overrides,
            boxed_fields=boxed_fields,
        )
        self.enum_generator = RustEnumGenerator(self)
        self.inline_structs: List[str] = []
        self.inline_object_names: Dict[Any, str] = {}
        self.claimed_inline_names: Set[str] = set()
        self.uses_strict_ref_helper = False
        self._used_const_names: Set[str] = {"NSID"}

    def get_file_extension(self) -> str:
        """Return `.rs` for Rust source files."""
        return ".rs"

    def unclaimed_inline_type_name(self, base_name: str, suffix: str = "Object") -> str:
        """Return `base_name` or a non-colliding suffixed variant inside the current module."""
        taken: Set[str] = set(self.claimed_inline_names)
        for def_name, def_schema in self.defs.items():
            if def_name == "main":
                if isinstance(def_schema, dict) and def_schema.get("type") != "token":
                    taken.add(self.main_name)
                if isinstance(def_schema, dict) and def_schema.get("type") in (
                    "query",
                    "procedure",
                    "subscription",
                ):
                    taken.update(_PRIMARY_HELPER_NAMES)
            elif isinstance(def_schema, dict) and def_schema.get("type") != "token":
                taken.add(
                    resolve_rust_def_type_name(
                        self.lexicon_id, def_name, lexicon_defs=self.defs
                    )
                )

        if base_name not in taken:
            self.claimed_inline_names.add(base_name)
            return base_name

        candidate = f"{base_name}{suffix}"
        counter = 2
        while candidate in taken:
            candidate = f"{base_name}{suffix}{counter}"
            counter += 1
        self.claimed_inline_names.add(candidate)
        return candidate

    def generate_inline_object(
        self,
        current_struct_name: str,
        name: str,
        schema: Dict[str, Any],
        context_identity=None,
    ) -> str:
        """Generate a nested-concept struct in the module for an inline object schema."""
        identity = (context_identity, current_struct_name, name)
        existing = self.inline_object_names.get(identity)
        if existing is not None:
            return existing

        base_name = f"{current_struct_name}{rust_pascal_case(name)}"
        struct_name = self.unclaimed_inline_type_name(base_name, suffix="Object")
        self.inline_object_names[identity] = struct_name

        rendered = self._render_struct(
            struct_name,
            schema,
            type_identifier=f"{self.lexicon_id}#{struct_name}",
            description=schema.get("description", ""),
            has_extra=True,
            encodes_type=False,
            lenient=True,
            is_record=False,
            context_identity=("inline-object", identity),
        )
        self.inline_structs.append(rendered)
        return struct_name

    def resolve_strict_ref_contract(self, ref: str) -> Tuple[List[str], str]:
        """Resolve allowed keys and canonical `$type` for `x-security-strict-decode`."""
        nsid, separator, fragment = ref.partition("#")
        if not nsid or nsid == self.lexicon_id:
            target_name = fragment if (separator and fragment) else "main"
            schema = self.defs.get(target_name)
            qualified_ref = (
                self.lexicon_id
                if target_name == "main"
                else f"{self.lexicon_id}#{target_name}"
            )
        else:
            qualified_ref = nsid if (not separator or fragment == "main") else ref
            registry = getattr(self.cycle_detector, "schemas_by_ref", None)
            schema = registry.get(qualified_ref) if registry is not None else None

        if not isinstance(schema, dict):
            raise ValueError(
                f"strict reference '{ref}' cannot be resolved to a canonical schema"
            )

        schema_type = schema.get("type")
        if schema_type == "record":
            object_schema = schema.get("record")
        elif schema_type == "object":
            object_schema = schema
        else:
            raise ValueError(
                f"strict reference '{qualified_ref}' must target an object or record schema"
            )

        properties = (
            object_schema.get("properties")
            if isinstance(object_schema, dict)
            else None
        )
        if not isinstance(properties, dict):
            raise ValueError(
                f"strict reference '{qualified_ref}' has no canonical object properties"
            )
        return sorted(properties.keys()), qualified_ref

    def _build_properties(
        self,
        properties: Dict[str, Any],
        required_fields: List[str],
        current_struct_name: str,
        *,
        nullable_fields: Optional[List[str]] = None,
        tri_state_nullable: bool = True,
        context_identity=None,
        def_name: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        nullable_set = set(nullable_fields or [])
        required_set = set(required_fields or [])
        used_idents: Set[str] = set()
        result: List[Dict[str, Any]] = []

        for name, prop_schema in properties.items():
            strict_decode = bool(prop_schema.get("x-security-strict-decode"))
            if strict_decode and prop_schema.get("type") != "ref":
                raise ValueError(
                    f"x-security-strict-decode is supported only on ref properties: '{name}'"
                )

            rust_type = self.type_converter.determine_type(
                name,
                prop_schema,
                list(required_set),
                current_struct_name,
                context_identity=context_identity,
                nullable_fields=list(nullable_set),
                tri_state_nullable=tri_state_nullable,
                def_name=def_name,
            )

            ident = rust_field_ident(name, used_idents)
            is_wire_optional = name not in required_set
            is_nullable = name in nullable_set
            tri_state = tri_state_nullable and is_wire_optional and is_nullable
            required_nullable = (not is_wire_optional) and is_nullable

            strict_allowed_keys = ""
            strict_type_id_literal = ""
            strict_target_type = ""
            if strict_decode:
                self.uses_strict_ref_helper = True
                allowed_keys, expected_type_id = self.resolve_strict_ref_contract(
                    prop_schema["ref"]
                )
                strict_allowed_keys = ", ".join(rust_string_literal(k) for k in allowed_keys)
                strict_type_id_literal = rust_string_literal(expected_type_id)
                strict_target_type = self.type_converter.convert_ref(prop_schema["ref"])
                if self.type_converter.should_box_property(
                    name, def_name=def_name, current_struct_name=current_struct_name
                ):
                    strict_target_type = f"Box<{strict_target_type}>"

            result.append({
                "name": name,
                "ident": ident,
                "wire_literal": rust_string_literal(name),
                "rust_type": rust_type,
                "description": prop_schema.get("description", ""),
                "wire_optional": is_wire_optional,
                "nullable": is_nullable,
                "tri_state": tri_state,
                "required_nullable": required_nullable,
                "in_new_params": not is_wire_optional,
                "strict_decode": strict_decode,
                "strict_allowed_keys": strict_allowed_keys,
                "strict_type_id_literal": strict_type_id_literal,
                "strict_target_type": strict_target_type,
            })

        return result

    @staticmethod
    def _pick_extra_name(props: List[Dict[str, Any]]) -> str:
        taken = {p["ident"] for p in props}
        for candidate in _EXTRA_DATA_CANDIDATES:
            if candidate not in taken:
                return candidate
        name = "extra_data_"
        while name in taken:
            name += "_"
        return name

    @staticmethod
    def _record_key_expr(key: Optional[str]) -> str:
        if not key or key == "any":
            return "petrel_core::RecordKeyType::Any"
        if key == "tid":
            return "petrel_core::RecordKeyType::Tid"
        if key == "nsid":
            return "petrel_core::RecordKeyType::Nsid"
        if key.startswith("literal:"):
            literal_val = key[len("literal:"):]
            return f"petrel_core::RecordKeyType::Literal({rust_string_literal(literal_val)})"
        return f"petrel_core::RecordKeyType::Literal({rust_string_literal(key)})"

    def _render_struct(
        self,
        name: str,
        object_schema: Dict[str, Any],
        *,
        type_identifier: str,
        description: str,
        has_extra: bool,
        encodes_type: bool,
        lenient: bool,
        is_record: bool = False,
        record_key: Optional[str] = None,
        context_identity=None,
        def_name: Optional[str] = None,
    ) -> str:
        props = self._build_properties(
            object_schema.get("properties", {}),
            object_schema.get("required", []),
            name,
            nullable_fields=object_schema.get("nullable", []),
            tri_state_nullable=True,
            context_identity=context_identity,
            def_name=def_name,
        )
        required_params = [p for p in props if p["in_new_params"]]
        cursor_expr: Optional[str] = None
        if not is_record:
            for prop in props:
                if prop["name"] == "cursor":
                    if prop["rust_type"] == "Option<String>":
                        cursor_expr = f"self.{prop['ident']}.as_deref()"
                    elif prop["rust_type"] == "String":
                        cursor_expr = f"Some(self.{prop['ident']}.as_str())"
                    break
        return self.template_manager.struct_template.render(
            name=name,
            lexicon_id=self.lexicon_id,
            type_identifier=type_identifier,
            description=description,
            properties=props,
            required_params=required_params,
            all_optional=len(required_params) == 0,
            has_extra=has_extra,
            extra_name=self._pick_extra_name(props) if has_extra else "extra_data",
            encodes_type=encodes_type,
            lenient=lenient,
            is_record=is_record,
            record_key_expr=self._record_key_expr(record_key) if is_record else "",
            cursor_expr=cursor_expr,
        )

    def _parameter_default_expr(
        self, prop_schema: Dict[str, Any], base_rust_type: str
    ) -> Optional[str]:
        if "default" not in prop_schema:
            return None
        value = prop_schema["default"]
        schema_type = prop_schema.get("type")
        if schema_type == "integer":
            if isinstance(value, bool) or not isinstance(value, int):
                raise ValueError(
                    f"{self.lexicon_id} query parameter default {value!r} is not an integer"
                )
            return str(value)
        if schema_type == "boolean":
            if not isinstance(value, bool):
                raise ValueError(
                    f"{self.lexicon_id} query parameter default {value!r} is not a boolean"
                )
            return "true" if value else "false"
        if schema_type == "string":
            if not isinstance(value, str):
                raise ValueError(
                    f"{self.lexicon_id} query parameter default {value!r} is not a string"
                )
            if "enum" in prop_schema:
                if value not in prop_schema["enum"]:
                    raise ValueError(
                        f"{self.lexicon_id} query parameter default {value!r} is not in its enum"
                    )
                return f"<{base_rust_type} as core::str::FromStr>::from_str({rust_string_literal(value)}).unwrap()"
            if base_rust_type == "String":
                return f"{rust_string_literal(value)}.to_owned()"
            return None
        raise ValueError(
            f"{self.lexicon_id} query parameter has default on unsupported type {schema_type!r}"
        )

    def _render_parameters(self, parameters: Optional[Dict[str, Any]]) -> Tuple[str, str]:
        if not parameters or not parameters.get("properties"):
            return "", "()"

        props_schema = parameters.get("properties", {})
        required_set = set(parameters.get("required") or [])
        nullable_set = set(parameters.get("nullable") or [])
        used_idents: Set[str] = set()
        props: List[Dict[str, Any]] = []

        for name, prop_schema in props_schema.items():
            base_type = self.type_converter._get_base_type(
                prop_schema,
                name,
                "Parameters",
                context_identity=("parameters",),
            )
            override_key = f"Parameters.{name}"
            if override_key in self.type_converter.property_type_overrides:
                base_type = self.type_converter.property_type_overrides[override_key]
                self.type_converter.used_property_type_overrides.add(override_key)

            default_expr = self._parameter_default_expr(prop_schema, base_type)
            is_wire_optional = name not in required_set
            is_option = is_wire_optional and (default_expr is None)
            rust_type = f"Option<{base_type}>" if is_option else base_type
            is_array = prop_schema.get("type") == "array"

            props.append({
                "name": name,
                "ident": rust_field_ident(name, used_idents),
                "wire_literal": rust_string_literal(name),
                "rust_type": rust_type,
                "description": prop_schema.get("description", ""),
                "is_array": is_array,
                "is_option": is_option,
                "default_expr": default_expr,
                "in_new_params": (not is_wire_optional) and (default_expr is None),
            })

        required_params = [p for p in props if p["in_new_params"]]
        cursor_ident = next(
            (
                p["ident"]
                for p in props
                if p["name"] == "cursor" and p["rust_type"] == "Option<String>"
            ),
            None,
        )
        code = self.template_manager.parameters_template.render(
            properties=props,
            required_params=required_params,
            all_optional=len(required_params) == 0,
            cursor_ident=cursor_ident,
        )
        return code, "Parameters"

    def _render_input(self, input_obj: Optional[Dict[str, Any]]) -> Tuple[str, str, str]:
        if not input_obj:
            return "", "()", "None"

        encoding = input_obj.get("encoding", "")
        encoding_expr = f"Some({rust_string_literal(encoding)})" if encoding else "None"
        input_schema = input_obj.get("schema")

        if is_schemaless_json_body(input_obj) or is_raw_bytes_schema(input_schema):
            return "", "petrel_core::Bytes", encoding_expr
        if encoding and encoding != "application/json":
            return "", "petrel_core::Bytes", encoding_expr
        if not isinstance(input_schema, dict):
            return "", "()", encoding_expr

        schema_type = input_schema.get("type")
        if schema_type == "ref":
            ref_type = self.type_converter.convert_ref(input_schema["ref"])
            alias = self.template_manager.type_alias_template.render(
                name="Input",
                target=ref_type,
                description=input_schema.get("description", ""),
            )
            return alias, "Input", encoding_expr
        if schema_type == "union":
            self.enum_generator.generate_enum_for_union_def(
                "InputUnion",
                input_schema.get("refs", []),
                closed=bool(input_schema.get("closed", False)),
                xrpc_input=True,
            )
            alias = self.template_manager.type_alias_template.render(
                name="Input",
                target="InputUnion",
                description=input_schema.get("description", ""),
            )
            return alias, "Input", encoding_expr
        if schema_type == "object":
            code = self._render_struct(
                "Input",
                input_schema,
                type_identifier=f"{self.lexicon_id}#Input",
                description=input_schema.get("description", ""),
                has_extra=False,
                encodes_type=False,
                lenient=False,
                context_identity=("input",),
            )
            return code, "Input", encoding_expr

        raise ValueError(
            f"{self.lexicon_id}: unsupported XRPC input schema type {schema_type!r}"
        )

    def _render_output(self, output_obj: Optional[Dict[str, Any]]) -> Tuple[str, str, str]:
        if not output_obj:
            return "", "()", "None"

        encoding = output_obj.get("encoding", "")
        encoding_expr = f"Some({rust_string_literal(encoding)})" if encoding else "None"
        output_schema = output_obj.get("schema")

        if is_schemaless_json_body(output_obj) or is_raw_bytes_schema(output_schema):
            return "", "petrel_core::Bytes", encoding_expr
        if encoding and encoding != "application/json":
            return "", "petrel_core::Bytes", encoding_expr
        if not isinstance(output_schema, dict):
            return "", "()", encoding_expr

        schema_type = output_schema.get("type")
        if schema_type == "ref":
            ref_type = self.type_converter.convert_ref(output_schema["ref"])
            alias = self.template_manager.type_alias_template.render(
                name="Output",
                target=ref_type,
                description=output_schema.get("description", ""),
            )
            return alias, "Output", encoding_expr
        if schema_type == "union":
            self.enum_generator.generate_enum_for_union_def(
                "OutputUnion",
                output_schema.get("refs", []),
                closed=bool(output_schema.get("closed", False)),
            )
            alias = self.template_manager.type_alias_template.render(
                name="Output",
                target="OutputUnion",
                description=output_schema.get("description", ""),
            )
            return alias, "Output", encoding_expr
        if schema_type == "object":
            code = self._render_struct(
                "Output",
                output_schema,
                type_identifier=f"{self.lexicon_id}#Output",
                description=output_schema.get("description", ""),
                has_extra=False,
                encodes_type=False,
                lenient=True,
                context_identity=("output",),
            )
            return code, "Output", encoding_expr

        raise ValueError(
            f"{self.lexicon_id}: unsupported XRPC output schema type {schema_type!r}"
        )

    def _render_errors(self, errors: Optional[List[Dict[str, Any]]]) -> Tuple[str, str]:
        if not errors:
            return "", "petrel_core::xrpc::UndeclaredError"

        used_variants: Set[str] = {"Unknown", "Self"}
        error_entries: List[Dict[str, str]] = []
        for err in errors:
            wire_name = err["name"]
            variant = rust_pascal_case(wire_name)
            while variant in used_variants:
                variant += "_"
            used_variants.add(variant)
            error_entries.append({
                "variant": variant,
                "wire_literal": rust_string_literal(wire_name),
                "description": err.get("description", ""),
            })

        code = self.template_manager.errors_template.render(errors=error_entries)
        return code, "Error"

    def _render_message(self, message_obj: Optional[Dict[str, Any]]) -> Tuple[str, List[str], str]:
        if not message_obj:
            return "", [], "()"
        schema = message_obj.get("schema")
        if not isinstance(schema, dict):
            return "", [], "()"

        schema_type = schema.get("type", "")
        if schema_type == "ref":
            target = self.type_converter.convert_ref(schema["ref"])
            alias = self.template_manager.type_alias_template.render(
                name="Message",
                target=target,
                description=schema.get("description", ""),
            )
            return alias, [], "Message"
        if schema_type == "union":
            raw_refs = schema.get("refs", [])
            self.enum_generator.generate_enum_for_union_def(
                "Message",
                raw_refs,
                closed=bool(schema.get("closed", False)),
            )
            union_meta = self.enum_generator.unions.get("Message", {})
            tags = [v["wire_tag"] for v in union_meta.get("variants", [])]
            return "", tags, "Message"
        if schema_type == "object":
            code = self._render_struct(
                "Message",
                schema,
                type_identifier=f"{self.lexicon_id}#Message",
                description=schema.get("description", ""),
                has_extra=True,
                encodes_type=False,
                lenient=True,
                context_identity=("message",),
            )
            return code, [], "Message"

        raise ValueError(
            f"{self.lexicon_id}: unsupported subscription message schema type {schema_type!r}"
        )

    def _render_space_declaration(self) -> str:
        title = self.main_def.get("title")
        title_expr = (
            f"Some({rust_string_literal(title)})"
            if isinstance(title, str)
            else "None"
        )
        collections = self.main_def.get("collections", [])
        return self.template_manager.space_template.render(
            space_name=self.main_name,
            lexicon_id=self.lexicon_id,
            key_type=self.main_def.get("key", "tid"),
            title_expr=title_expr,
            collections=collections,
        )

    def _render_definitions(self) -> str:
        chunks: List[str] = []
        for def_name, def_schema in self.defs.items():
            if def_name == "main":
                continue
            if not isinstance(def_schema, dict):
                continue

            def_type = def_schema.get("type", "")
            type_name = resolve_rust_def_type_name(
                self.lexicon_id, def_name, lexicon_defs=self.defs
            )
            desc = def_schema.get("description", "")

            if def_type == "object":
                chunks.append(
                    self._render_struct(
                        type_name,
                        def_schema,
                        type_identifier=f"{self.lexicon_id}#{def_name}",
                        description=desc,
                        has_extra=True,
                        encodes_type=False,
                        lenient=True,
                        context_identity=("definition", def_name),
                        def_name=def_name,
                    )
                )
            elif def_type == "string" and "enum" in def_schema:
                self.enum_generator.generate_closed_string_enum(
                    type_name,
                    def_schema["enum"],
                    ("definition", self.lexicon_id, def_name),
                )
            elif def_type == "string" and "knownValues" in def_schema:
                self.enum_generator.generate_enum_from_known_values(
                    type_name, def_schema["knownValues"]
                )
            elif def_type == "string":
                target = self.type_converter._convert_string_type(def_schema.get("format"))
                chunks.append(
                    self.template_manager.type_alias_template.render(
                        name=type_name, target=target, description=desc
                    )
                )
            elif def_type == "bytes":
                chunks.append(
                    self.template_manager.type_alias_template.render(
                        name=type_name, target="petrel_core::Bytes", description=desc
                    )
                )
            elif def_type == "blob":
                chunks.append(
                    self.template_manager.type_alias_template.render(
                        name=type_name, target="petrel_core::Blob", description=desc
                    )
                )
            elif def_type == "cid-link":
                chunks.append(
                    self.template_manager.type_alias_template.render(
                        name=type_name, target="petrel_core::CidLink", description=desc
                    )
                )
            elif def_type == "union":
                self.enum_generator.generate_enum_for_union_def(
                    type_name,
                    def_schema.get("refs", []),
                    closed=bool(def_schema.get("closed", False)),
                )
            elif def_type == "array":
                items = def_schema.get("items", {})
                if isinstance(items, dict) and items.get("type") == "union":
                    item_union_name = self.unclaimed_inline_type_name(
                        f"{type_name}Item", suffix="Union"
                    )
                    self.enum_generator.generate_enum_for_union_array(
                        type_name,
                        "Item",
                        items.get("refs", []),
                        closed=bool(items.get("closed", False)),
                        union_name=item_union_name,
                    )
                    item_type = item_union_name
                else:
                    item_type = self.type_converter._get_array_item_type(
                        def_schema,
                        def_name,
                        type_name,
                        context_identity=("definition", def_name),
                    )
                chunks.append(
                    self.template_manager.type_alias_template.render(
                        name=type_name, target=f"Vec<{item_type}>", description=desc
                    )
                )
            elif def_type == "token":
                const_name = f"TOKEN_{rust_snake_case(def_name).upper()}"
                while const_name in self._used_const_names:
                    const_name += "_"
                self._used_const_names.add(const_name)
                token_uri = rust_string_literal(f"{self.lexicon_id}#{def_name}")
                doc = ""
                if desc:
                    doc = self.template_manager.env.filters["escape_doc"](desc) + "\n"
                chunks.append(f"{doc}pub const {const_name}: &str = {token_uri};")
            else:
                raise ValueError(
                    f"unhandled lexicon def shape '{def_type}' for "
                    f"'{self.lexicon_id}#{def_name}'"
                )

        return "\n\n".join(c for c in chunks if c)

    def convert(self) -> str:
        """Generate complete Rust module source for this lexicon."""
        main_type = self.main_def.get("type", "") if self.main_def else ""

        record_code = ""
        main_object_code = ""
        parameters_code = ""
        input_code = ""
        output_code = ""
        message_code = ""
        errors_code = ""
        endpoint_code = ""
        space_code = ""

        if not self.main_def:
            pass
        elif main_type == "record":
            record_schema = self.main_def["record"]
            record_code = self._render_struct(
                self.main_name,
                record_schema,
                type_identifier=self.lexicon_id,
                description=self.description,
                has_extra=True,
                encodes_type=True,
                lenient=True,
                is_record=True,
                record_key=self.main_def.get("key"),
                def_name="main",
            )
        elif main_type == "object":
            main_object_code = self._render_struct(
                self.main_name,
                self.main_def,
                type_identifier=self.lexicon_id,
                description=self.description,
                has_extra=True,
                encodes_type=False,
                lenient=True,
                is_record=False,
                def_name="main",
            )
        elif main_type == "space":
            space_code = self._render_space_declaration()
        elif main_type == "query":
            parameters_code, params_type = self._render_parameters(
                self.main_def.get("parameters")
            )
            output_code, output_type, output_enc = self._render_output(
                self.main_def.get("output")
            )
            errors_code, error_type = self._render_errors(self.main_def.get("errors"))
            endpoint_code = self.template_manager.endpoint_template.render(
                endpoint_name=self.main_name,
                lexicon_id=self.lexicon_id,
                method_variant="Query",
                input_encoding_expr="None",
                output_encoding_expr=output_enc,
                params_type=params_type,
                input_type="()",
                output_type=output_type,
                error_type=error_type,
            )
        elif main_type == "procedure":
            parameters_code, params_type = self._render_parameters(
                self.main_def.get("parameters")
            )
            input_code, input_type, input_enc = self._render_input(
                self.main_def.get("input")
            )
            output_code, output_type, output_enc = self._render_output(
                self.main_def.get("output")
            )
            errors_code, error_type = self._render_errors(self.main_def.get("errors"))
            endpoint_code = self.template_manager.endpoint_template.render(
                endpoint_name=self.main_name,
                lexicon_id=self.lexicon_id,
                method_variant="Procedure",
                input_encoding_expr=input_enc,
                output_encoding_expr=output_enc,
                params_type=params_type,
                input_type=input_type,
                output_type=output_type,
                error_type=error_type,
            )
        elif main_type == "subscription":
            parameters_code, params_type = self._render_parameters(
                self.main_def.get("parameters")
            )
            message_code, known_tags, message_type = self._render_message(
                self.main_def.get("message")
            )
            errors_code, error_type = self._render_errors(self.main_def.get("errors"))
            subprotocol = self.main_def.get("subprotocol")
            subprotocol_expr = (
                f"Some({rust_string_literal(subprotocol)})"
                if isinstance(subprotocol, str) and subprotocol
                else "None"
            )
            endpoint_code = self.template_manager.subscription_template.render(
                endpoint_name=self.main_name,
                lexicon_id=self.lexicon_id,
                subprotocol_expr=subprotocol_expr,
                known_message_types=known_tags,
                params_type=params_type,
                message_type=message_type,
                error_type=error_type,
            )
        elif main_type == "permission-set":
            # Permission-sets are metadata constants; non-main defs still emit below.
            pass
        elif main_type == "string" and "enum" in self.main_def:
            self.enum_generator.generate_closed_string_enum(
                self.main_name,
                self.main_def["enum"],
                ("definition", self.lexicon_id, "main"),
            )
        elif main_type == "string" and "knownValues" in self.main_def:
            self.enum_generator.generate_enum_from_known_values(
                self.main_name, self.main_def["knownValues"]
            )
        elif main_type == "string":
            target = self.type_converter._convert_string_type(self.main_def.get("format"))
            main_object_code = self.template_manager.type_alias_template.render(
                name=self.main_name, target=target, description=self.description
            )
        elif main_type == "bytes":
            main_object_code = self.template_manager.type_alias_template.render(
                name=self.main_name, target="petrel_core::Bytes", description=self.description
            )
        elif main_type == "blob":
            main_object_code = self.template_manager.type_alias_template.render(
                name=self.main_name, target="petrel_core::Blob", description=self.description
            )
        elif main_type == "cid-link":
            main_object_code = self.template_manager.type_alias_template.render(
                name=self.main_name, target="petrel_core::CidLink", description=self.description
            )
        elif main_type == "union":
            self.enum_generator.generate_enum_for_union_def(
                self.main_name,
                self.main_def.get("refs", []),
                closed=bool(self.main_def.get("closed", False)),
            )
        elif main_type == "array":
            items = self.main_def.get("items", {})
            if isinstance(items, dict) and items.get("type") == "union":
                item_union_name = self.unclaimed_inline_type_name(
                    f"{self.main_name}Item", suffix="Union"
                )
                self.enum_generator.generate_enum_for_union_array(
                    self.main_name,
                    "Item",
                    items.get("refs", []),
                    closed=bool(items.get("closed", False)),
                    union_name=item_union_name,
                )
                item_type = item_union_name
            else:
                item_type = self.type_converter._get_array_item_type(
                    self.main_def,
                    "main",
                    self.main_name,
                    context_identity=("definition", "main"),
                )
            main_object_code = self.template_manager.type_alias_template.render(
                name=self.main_name, target=f"Vec<{item_type}>", description=self.description
            )
        elif main_type == "token":
            token_uri = rust_string_literal(f"{self.lexicon_id}#main")
            main_object_code = f"pub const TOKEN_MAIN: &str = {token_uri};"
        else:
            raise ValueError(
                f"unhandled lexicon main def shape '{main_type}' for '{self.lexicon_id}'"
            )

        definitions_code = self._render_definitions()
        self.type_converter.assert_all_overrides_used()

        strict_ref_helper = (
            self.template_manager.strict_ref_helper_template.render()
            if self.uses_strict_ref_helper
            else ""
        )

        all_enums = [*self.inline_structs, *self.enum_generator.enums_code]
        enums_code = "\n\n".join(c for c in all_enums if c)

        rendered = self.template_manager.module_template.render(
            lexicon_version=self.lexicon_version,
            lexicon_id=self.lexicon_id,
            description=self.description,
            strict_ref_helper=strict_ref_helper,
            space_declaration=space_code,
            record=record_code,
            main_object=main_object_code,
            parameters=parameters_code,
            input=input_code,
            output=output_code,
            message=message_code,
            errors=errors_code,
            endpoint=endpoint_code,
            definitions=definitions_code,
            enums=enums_code,
        )
        return self._collapse_blank_lines(rendered)

    @staticmethod
    def _collapse_blank_lines(code: str) -> str:
        lines = code.splitlines()
        out: List[str] = []
        prev_blank = False
        for line in lines:
            is_blank = not line.strip()
            if is_blank and prev_blank:
                continue
            out.append(line)
            prev_blank = is_blank
        text = "\n".join(out).rstrip() + "\n"
        return text
