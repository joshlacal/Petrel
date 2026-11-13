import json
import re
from typing import Dict, List, Any, Optional
from utils import (
    convert_to_camel_case,
    lowercase_first_letter,
    namespace_type_path,
    normalize_ref,
    swift_member_name,
)
from templates import TemplateManager, sanitize_swift_keyword
from enum_generator import EnumGenerator
from type_converter import TypeConverter
from base_code_generator import BaseCodeGenerator

# Swift types `Parametrizable.asQueryItems()` (Sources/Petrel/Core/Utils/QueryParameters.swift)
# can put on the wire, each through a QueryParameterConvertible conformance. A query
# parameter of any other type would never reach the server, so generation stops instead.
# Adding a type here takes that conformance plus a field in
# QueryParametersTests.EveryLeafParameters.
QUERY_ENCODABLE_SWIFT_TYPES = frozenset({
    "String", "Int", "Bool",
    "CID", "CIDString", "ATProtocolDate", "URI", "ATProtocolURI", "SpaceRef", "ATIdentifier",
    "DID", "Handle", "NSID", "TID", "RecordKey", "LanguageCodeContainer",
})

# Static members every generated lexicon container may declare. A token constant
# with one of these names gets a `Token` suffix instead of redeclaring the member.
RESERVED_CONTAINER_MEMBERS = frozenset({
    "typeIdentifier", "recordKeyType", "permissionSet", "spaceDeclaration",
    "endpointDescriptor", "knownMessageTypes",
})

# Name of the property that keeps undeclared wire fields, and its fallbacks for an
# object whose Lexicon already declares a property with that name.
EXTRA_FIELDS_NAMES = ("extraFields", "undeclaredFields", "_extraFields")

# Primary definition types: one per lexicon, always named `main`, never a ref target.
PRIMARY_TYPES = frozenset({"record", "query", "procedure", "subscription", "permission-set"})


class SwiftCodeGenerator(BaseCodeGenerator):
    def __init__(
        self,
        lexicon: Dict[str, Any],
        cycle_detector=None,
        emit_server_contracts=False,
        emit_xrpc_error_parsing=False,
        property_type_overrides: Optional[Dict[str, str]] = None,
    ):
        """
        emit_xrpc_error_parsing is accepted for manifest compatibility and ignored:
        every generated call now throws the server's `{error, message}` envelope.

        property_type_overrides maps `"<StructName>.<property>"` (for example
        `"Output.didDoc"`) to a Swift type that replaces the generated one for that
        property of this lexicon. It comes from the manifest
        (`swift.property_type_overrides[<nsid>]`).
        """
        super().__init__(lexicon, cycle_detector)
        self.property_type_overrides = dict(property_type_overrides or {})
        self.used_property_type_overrides = set()
        self.inline_objects = {}
        self.inline_object_names = {}
        self.parameter_properties = []
        self.struct_name = convert_to_camel_case(self.lexicon_id)
        self.conformance = ""
        self.enums = ""
        self.generated_unions = set()
        self.enum_definitions = {}
        self.cycle_detector = cycle_detector
        self.emit_server_contracts = emit_server_contracts
        self.emit_xrpc_error_parsing = emit_xrpc_error_parsing

        self.token_descriptions = {}
        self.generated_tokens = set()
        self.closed_enums_by_identity = {}
        self.closed_enum_identity_by_name = {}
        self.input_properties = []

        self.template_manager = TemplateManager()
        self.enum_generator = EnumGenerator(self)
        self.type_converter = TypeConverter(self)

        self.main_def = self.handle_main_def()
        self.server_input_definitions = (
            self.find_server_input_definitions()
            if self.emit_server_contracts
            else set()
        )

    def get_file_extension(self) -> str:
        return '.swift'
    def handle_main_def(self):
        main_def = self.defs.get('main', {})
        main_def_type = main_def.get('type')

        if main_def_type == 'object':
            return self.handle_object_type(main_def)
        elif main_def_type == 'procedure':
            return self.handle_procedure_type(main_def)
        elif main_def_type == 'subscription':
            return self.handle_subscription_type(main_def)
        else:
            return main_def

    def handle_object_type(self, main_def):
        return main_def

    def handle_procedure_type(self, main_def):
        return main_def

    def handle_subscription_type(self, main_def):
        return main_def

    def find_server_input_definitions(self):
        """Return local definitions transitively reachable from an XRPC input."""
        main_input = self.defs.get('main', {}).get('input')
        if not isinstance(main_input, dict):
            return set()
        input_schema = main_input.get('schema')
        if not isinstance(input_schema, dict):
            return set()

        reachable = set()
        visiting = set()

        def local_definition_name(ref):
            if not isinstance(ref, str):
                return None
            if ref.startswith('#'):
                name = ref[1:]
            else:
                nsid, separator, fragment = ref.partition('#')
                if nsid != self.lexicon_id:
                    return None
                name = fragment if separator else 'main'
            return name if name in self.defs else None

        def visit(node):
            if not isinstance(node, dict):
                return

            if node.get('type') == 'ref':
                name = local_definition_name(node.get('ref'))
                if name is not None and name not in visiting:
                    reachable.add(name)
                    visiting.add(name)
                    visit(self.defs[name])
                    visiting.remove(name)

            refs = node.get('refs')
            if isinstance(refs, list):
                for ref in refs:
                    visit({'type': 'ref', 'ref': ref})

            properties = node.get('properties')
            if isinstance(properties, dict):
                for property_schema in properties.values():
                    visit(property_schema)

            visit(node.get('items'))
            visit(node.get('record'))

        visit(input_schema)
        return reachable

    def generate_properties(
        self,
        properties,
        required_fields,
        current_struct_name,
        context_identity=None,
        nullable_fields=None,
        server_input=False,
        tri_state_nullable=True,
    ):
        nullable_fields = nullable_fields or []
        swift_properties = []
        used_identifiers = {}
        for name, prop in properties.items():
            swift_type = self.type_converter.determine_swift_type(
                name, prop, required_fields, current_struct_name,
                context_identity=context_identity,
            )
            override_key = f"{current_struct_name}.{name}"
            if override_key in self.property_type_overrides:
                swift_type = self.property_type_overrides[override_key]
                self.used_property_type_overrides.add(override_key)
            description = prop.get('description', '')
            is_wire_optional = name not in required_fields
            is_nullable = name in nullable_fields
            is_optional = is_wire_optional or is_nullable
            # Optional AND nullable: "absent", `null` and a value are three distinct
            # wire states (`putRecord.swapRecord: null` means "must not exist").
            # `T?` can only carry two of them, so the value is wrapped.
            tri_state = tri_state_nullable and is_wire_optional and is_nullable
            wrapped_type = swift_type
            if tri_state:
                swift_type = f"ATProtoNullable<{swift_type}>"

            ident_bare = swift_member_name(name)
            while ident_bare in used_identifiers:
                # Two wire names that camel-case to the same identifier (`a-b`, `aB`).
                ident_bare += "_"
            used_identifiers[ident_bare] = name
            ident = sanitize_swift_keyword(ident_bare)
            strict_decode = prop.get('x-security-strict-decode', False)
            if strict_decode and prop.get('type') != 'ref':
                raise ValueError(
                    f"x-security-strict-decode is supported only on ref properties: '{name}'"
                )
            strict_allowed_keys_literal = None
            strict_type_identifier_literal = None
            if strict_decode:
                allowed_keys, expected_type_identifier = self.resolve_strict_ref_contract(
                    prop['ref']
                )
                strict_allowed_keys_literal = ", ".join(
                    json.dumps(key)
                    for key in allowed_keys
                )
                strict_type_identifier_literal = json.dumps(expected_type_identifier)

            # Check if this property should be boxed to break a circular reference
            should_box = False
            if self.cycle_detector:
                # Build the full Swift type name for checking
                swift_full_type = convert_to_camel_case(self.lexicon_id)
                if current_struct_name != convert_to_camel_case(self.lexicon_id):
                    swift_full_type = f"{swift_full_type}.{current_struct_name}"
                should_box = self.cycle_detector.should_box_property(swift_full_type, name)

            swift_properties.append({
                'name': name,
                'ident': ident,
                'ident_bare': ident_bare,
                'key': ident,
                'key_needs_raw_value': ident_bare != name,
                'var': ident_bare,
                'tri_state': tri_state,
                'wrapped_type': wrapped_type,
                'type': swift_type,
                'optional': is_optional,
                'wire_optional': is_wire_optional,
                'required_nullable': not is_wire_optional and is_nullable,
                'nullable': is_nullable,
                'server_input': server_input,
                'description': description,
                'boxed': should_box,
                'strict_decode': strict_decode,
                # Kept for the output template's established compatibility branch.
                'strict_optional_decode': strict_decode,
                'strict_allowed_keys_literal': strict_allowed_keys_literal,
                'strict_type_identifier_literal': strict_type_identifier_literal,
            })
        return swift_properties

    @staticmethod
    def simple_property(name: str, swift_type: str) -> Dict[str, Any]:
        """A required property outside any Lexicon schema (the `data` of a binary body)."""
        return {
            'name': name, 'ident': name, 'ident_bare': name, 'key': name,
            'key_needs_raw_value': False, 'var': name, 'tri_state': False,
            'wrapped_type': swift_type, 'type': swift_type, 'optional': False,
            'wire_optional': False, 'required_nullable': False, 'nullable': False,
            'server_input': False, 'description': '', 'boxed': False,
            'strict_decode': False, 'strict_optional_decode': False,
            'strict_allowed_keys_literal': None, 'strict_type_identifier_literal': None,
        }

    @staticmethod
    def object_context(
        properties,
        *,
        encodes_type: bool,
        value_semantics: bool,
        lenient: bool,
        extra_fields: bool,
        server_input: bool = False,
    ) -> Dict[str, Any]:
        """Rendering switches for templates/objectMembers.jinja (documented there)."""
        taken = {prop['ident_bare'] for prop in properties}
        extra_name = next(name for name in EXTRA_FIELDS_NAMES if name not in taken)
        # Strict mode matters for an optional property in two places: the lenient
        # catch block, and the null check of a property that is not nullable.
        uses_strict_flag = any(
            prop['wire_optional'] and not prop['strict_decode']
            and (lenient or (not prop['nullable'] and not server_input))
            for prop in properties
        )
        keeps_malformed = lenient and extra_fields and any(
            prop['wire_optional'] and not prop['strict_decode'] for prop in properties
        )
        return {
            'uses_strict_flag': uses_strict_flag,
            'keeps_malformed': keeps_malformed,
            'encodes_type': encodes_type,
            'value_semantics': value_semantics,
            'lenient': lenient,
            'extra_fields': extra_fields,
            'extra_name': extra_name,
            'server_input': server_input,
        }

    def generate_inline_object(self, current_struct_name, name, schema, context_identity=None) -> str:
        """Nested struct for an object schema written inline in a property.

        An inline object has no name of its own, so it is named after the struct and
        property that contain it (`ViewMeta` for `view.meta`) and never carries `$type`.
        """
        identity = (context_identity, current_struct_name, name)
        existing = self.inline_object_names.get(identity)
        if existing is not None:
            return existing
        base_name = f"{convert_to_camel_case(current_struct_name)}{convert_to_camel_case(name)}"
        struct_name = self.unclaimed_inline_type_name(base_name)
        if struct_name in self.inline_objects:
            raise ValueError(
                f"{self.lexicon_id}: inline object type name '{struct_name}' is produced by two "
                f"different properties ({self.inline_objects[struct_name]!r} and {identity!r})"
            )
        self.inline_objects[struct_name] = identity
        self.inline_object_names[identity] = struct_name
        properties = self.generate_properties(
            schema.get('properties', {}),
            schema.get('required', []),
            struct_name,
            context_identity=("inline-object", identity),
            nullable_fields=schema.get('nullable', []),
        )
        template = self.template_manager.env.get_template('inlineObject.jinja')
        self.enums += template.render(
            name=struct_name,
            description=schema.get('description', ''),
            properties=properties,
            ctx=self.object_context(
                properties, encodes_type=False, value_semantics=True, lenient=True, extra_fields=True,
            ),
        ) + "\n\n"
        return struct_name

    # Types every lexicon container may declare besides its named definitions.
    FIXED_CONTAINER_TYPE_NAMES = frozenset({"Parameters", "Input", "Output", "Message", "Error"})

    def unclaimed_inline_type_name(self, base_name: str) -> str:
        """`base_name`, or `<base_name>Object[N]` when the container already has a type
        of that name.

        An inline object is named after its struct and property (`ViewMeta` for
        `view.meta`), which can be the name of a named definition (`viewMeta`) or of
        another generated type. A named definition keeps its name, since other
        lexicons refer to it as `Container.Name`; nothing refers to an inline
        object's type by name from outside, so the inline object yields.
        """
        taken = set(self.FIXED_CONTAINER_TYPE_NAMES)
        taken.update(convert_to_camel_case(name) for name in self.defs if name != 'main')
        taken.update(f"Defs{convert_to_camel_case(name)}" for name, schema in self.defs.items()
                     if isinstance(schema, dict) and schema.get('type') == 'string' and 'enum' in schema)
        taken.update(self.closed_enum_identity_by_name)
        if base_name not in taken:
            return base_name
        candidate = f"{base_name}Object"
        suffix = 2
        while candidate in taken or candidate in self.inline_objects:
            candidate = f"{base_name}Object{suffix}"
            suffix += 1
        return candidate

    def resolve_strict_ref_contract(self, ref: str) -> tuple[List[str], str]:
        nsid, separator, fragment = ref.partition('#')
        if not nsid or nsid == self.lexicon_id:
            target_name = fragment if separator else 'main'
            schema = self.defs.get(target_name)
            qualified_ref = (
                self.lexicon_id
                if target_name == 'main'
                else f"{self.lexicon_id}#{target_name}"
            )
        else:
            qualified_ref = nsid if not separator or fragment == 'main' else ref
            registry = getattr(self.cycle_detector, 'schemas_by_ref', None)
            schema = registry.get(qualified_ref) if registry is not None else None

        if not isinstance(schema, dict):
            raise ValueError(
                f"strict reference '{ref}' cannot be resolved to a canonical schema"
            )

        schema_type = schema.get('type')
        if schema_type == 'record':
            object_schema = schema.get('record')
        elif schema_type == 'object':
            object_schema = schema
        else:
            raise ValueError(
                f"strict reference '{qualified_ref}' must target an object or record schema"
            )

        properties = (
            object_schema.get('properties')
            if isinstance(object_schema, dict)
            else None
        )
        if not isinstance(properties, dict):
            raise ValueError(
                f"strict reference '{qualified_ref}' has no canonical object properties"
            )
        return sorted(properties.keys()), qualified_ref

    def generate_query_parameters(self, parameters: Optional[Dict[str, Any]]) -> str:
        if not parameters:
            return ""
        properties = self.generate_properties(
            parameters.get('properties', {}),
            parameters.get('required', []),
            "Parameters",
            nullable_fields=parameters.get('nullable', []),
            tri_state_nullable=False,
        )
        for prop in properties:
            schema = parameters['properties'][prop['name']]
            self.check_query_parameter_encodable(prop, schema)
            prop['default_literal'] = self.parameter_default_literal(prop, schema)
        self.parameter_properties = properties
        return self.template_manager.query_parameters_template.render(properties=properties)

    def parameter_default_literal(self, prop: Dict[str, Any], schema: Dict[str, Any]) -> Optional[str]:
        """The Swift literal for a parameter's Lexicon `default`, or None.

        The Lexicon specification says a client should send a parameter's default
        (so caches see one request, not two), so the default becomes the
        initializer's default argument: `limit: Int? = 50`. A caller can still pass
        `nil` to leave the parameter out.
        """
        if 'default' not in schema:
            return None
        value = schema['default']
        schema_type = schema.get('type')
        where = f"{self.lexicon_id} query parameter '{prop['name']}'"
        if schema_type == 'integer':
            if isinstance(value, bool) or not isinstance(value, int):
                raise ValueError(f"{where} has default {value!r}, which is not an integer")
            return str(value)
        if schema_type == 'boolean':
            if not isinstance(value, bool):
                raise ValueError(f"{where} has default {value!r}, which is not a boolean")
            return 'true' if value else 'false'
        if schema_type == 'string':
            if not isinstance(value, str):
                raise ValueError(f"{where} has default {value!r}, which is not a string")
            if 'enum' in schema:
                if value not in schema['enum']:
                    raise ValueError(f"{where} has default '{value}', which is not in its enum")
                return '.' + self.enum_generator._case_identifier(value)
            if prop['type'] == 'String':
                return self.enum_generator._swift_string_literal(value)
            # A string format with its own Swift type (DID, Handle, ...) has no
            # literal form; the parameter is left out unless the caller sets it.
            return None
        raise ValueError(
            f"{where} has a default, which the Lexicon allows only on boolean, integer and string"
        )

    def check_query_parameter_encodable(self, prop: Dict[str, Any], schema: Dict[str, Any]) -> None:
        leaf = schema.get('items', {}) if schema.get('type') == 'array' else schema
        if leaf.get('type') == 'string' and 'enum' in leaf:
            return  # a generated closed string enum, sent as its raw value
        leaf_type = prop['type'].strip('[]?')
        if leaf_type not in QUERY_ENCODABLE_SWIFT_TYPES:
            raise ValueError(
                f"{self.lexicon_id} query parameter '{prop['name']}' is a {prop['type']}, "
                "which Parametrizable.asQueryItems() cannot encode; give the type a "
                "QueryParameterConvertible conformance and add it to QUERY_ENCODABLE_SWIFT_TYPES"
            )

    def generate_input_struct(self, input_obj: Optional[Dict[str, Any]]) -> str:
        if not input_obj:
            return ""

        encoding = input_obj.get('encoding', '')
        is_binary = encoding != '' and encoding != 'application/json'
        input_schema = input_obj.get('schema')

        if is_binary:
            # A non-JSON body (CAR file, blob, video) is opaque bytes.
            properties = [self.simple_property("data", "Data")]
        elif not isinstance(input_schema, dict):
            return ""
        elif input_schema.get('type') == 'ref':
            # The request body IS the referenced object. Wrapping it in a struct
            # with a `data` property would put `{"data": {...}}` on the wire.
            ref_type = self.type_converter.convert_ref(input_schema['ref'])
            return f"\n    public typealias Input = {ref_type}\n"
        elif input_schema.get('type') == 'union':
            # A union body is one of the referenced objects, discriminated by `$type`.
            self.enum_generator.generate_enum_for_union_def(
                "InputUnion", input_schema.get('refs', []), closed=input_schema.get('closed', False),
            )
            return "\n    public typealias Input = InputUnion\n"
        else:
            properties = self.generate_properties(
                input_schema.get('properties', {}),
                input_schema.get('required', []),
                "Input",
                nullable_fields=input_schema.get('nullable', []),
                server_input=self.emit_server_contracts,
            )
            self.input_properties = properties

        return self.template_manager.input_struct_template.render(
            properties=properties,
            ctx=self.object_context(
                properties,
                encodes_type=False,
                value_semantics=False,
                lenient=False,
                extra_fields=False,
                server_input=self.emit_server_contracts and not is_binary,
            ),
        )

    def generate_output_struct(self, output_obj: Optional[Dict[str, Any]]) -> str:
        if not output_obj:
            return ""

        encoding = output_obj.get('encoding', '')
        output_schema = output_obj.get('schema', {})
        if not isinstance(output_schema, dict):
            output_schema = {}
        output_properties = output_schema.get('properties', {})
        if not isinstance(output_properties, dict):
            output_properties = {}
        output_properties = {
            name: schema for name, schema in output_properties.items()
            if isinstance(schema, dict)
        }
        output_schema = {**output_schema, 'properties': output_properties}

        context = {
            'conformance': ": ATProtocolCodable" if encoding == "application/json" else "",
            'is_type_alias': False,
            'properties': [],
            'type_alias_target': None,
        }

        context['is_binary'] = False
        if output_schema.get('type') == 'ref':
            context['is_type_alias'] = True
            context['type_alias_target'] = self.type_converter.convert_ref(output_schema['ref'])
        elif output_schema.get('type') == 'union':
            # A union body is one of the referenced objects, discriminated by `$type`.
            self.enum_generator.generate_enum_for_union_def(
                "OutputUnion", output_schema.get('refs', []), closed=output_schema.get('closed', False),
            )
            context['is_type_alias'] = True
            context['type_alias_target'] = "OutputUnion"
        elif encoding == "*/*":
            context['is_binary'] = True
        elif not output_schema or (not output_schema.get('properties') and output_schema.get('type') != 'object'):
            # No schema or schema without properties (binary data case)
            # For encodings like application/vnd.ipld.car, application/jsonl without schema
            context['is_binary'] = bool(encoding and encoding != 'application/json')
        else:
            context['properties'] = self.generate_properties(
                output_schema.get('properties', {}),
                output_schema.get('required', []),
                "Output",
                nullable_fields=output_schema.get('nullable', []),
            )
        context['ctx'] = self.object_context(
            context['properties'], encodes_type=False, value_semantics=False, lenient=True, extra_fields=False,
        )

        return self.template_manager.output_struct_template.render(**context)

    def validate_output_local_refs(self) -> None:
        """Reject references to missing local definitions in every output shape."""
        output = self.main_def.get('output')
        if not isinstance(output, dict):
            return
        schema = output.get('schema')
        if not isinstance(schema, dict):
            return

        def validate(node: Any, path: str) -> None:
            if not isinstance(node, dict):
                return
            if node.get('type') == 'ref':
                ref = node.get('ref', '')
                if isinstance(ref, str) and ref.startswith('#') and ref[1:] not in self.defs:
                    raise ValueError(
                        f"output {path} references missing local definition '{ref}'"
                    )
            properties = node.get('properties')
            if isinstance(properties, dict):
                for name, property_schema in properties.items():
                    validate(property_schema, f"property '{name}'")
            validate(node.get('items'), f"{path} array item")

        validate(schema, "schema")

    def generate_errors_enum(self, errors: Optional[List[Dict[str, str]]]) -> str:
        if not errors:
            return ""
        return self.template_manager.errors_enum_template.render(errors=errors)

    def generate_message_union(self, message_obj: Optional[Dict[str, Any]]) -> str:
        if not message_obj:
            return ""
        
        schema = message_obj.get('schema', {})
        if schema.get('type') == 'ref':
            # Message schema delegating to a named def (usually a union def in
            # the corpus's defs lexicon). The subscription client template
            # references `<Lexicon>.Message`, so alias it to the target type.
            target = self.type_converter.convert_ref(schema['ref'])
            return f"\n    public typealias Message = {target}\n"
        if schema.get('type') != 'union':
            return ""
        
        refs = schema.get('refs', [])
        variants = []
        
        for ref in refs:
            type_id = normalize_ref(ref, self.lexicon_id)
            type_name = self.type_converter.convert_ref(ref)
            
            # Create a case name from the type
            case_name = type_name.split('.')[-1]
            case_name = case_name[0].lower() + case_name[1:] if case_name else case_name
            
            variants.append({
                'case_name': case_name,
                'type': type_name,
                'type_id': type_id
            })
        
        return self.template_manager.message_union_template.render(variants=variants)

    def is_union_array(self, def_schema):
        return def_schema.get('type') == 'array' and 'refs' in def_schema.get('items', {})

    def generate_lex_definitions(self):
        lex_definitions = {}
        for name, def_schema in self.defs.items():
            current_struct_name = convert_to_camel_case(name)
            def_type = def_schema.get('type', "")

            if self.is_union_array(def_schema):
                refs = def_schema['items']['refs']
                self.enum_generator.generate_enum_for_union_array(
                    current_struct_name, name, refs, closed=def_schema['items'].get('closed', False),
                )
                continue
            if name == 'main' and def_type in PRIMARY_TYPES | {'object', 'space'}:
                # Rendered by convert() as the lexicon container itself.
                continue
            if def_type == "object":
                properties = self.generate_properties(
                    def_schema.get('properties', {}), def_schema.get('required', []),
                    current_struct_name, context_identity=("definition", name),
                    nullable_fields=def_schema.get('nullable', []),
                )
                server_input = name in self.server_input_definitions
                lex_definitions[current_struct_name] = {
                    'wire_fragment': name,
                    'description': def_schema.get('description', ''),
                    'properties': properties,
                    'conformance': ": ATProtocolCodable, ATProtocolValue",
                    # A named object does not write `$type` itself. The Lexicon
                    # specification says data reached through a plain `ref` should
                    # not carry it; where it is required (a union variant, a value in
                    # an `unknown` field) the union enum or the value container adds
                    # it. Records, which always carry `$type`, write their own.
                    'ctx': self.object_context(
                        properties,
                        encodes_type=False,
                        value_semantics=True,
                        lenient=not server_input,
                        extra_fields=True,
                        server_input=server_input,
                    ),
                }
            elif def_type == "token":
                self.generate_token_constant(name, def_schema)
            elif def_type == "string" and 'enum' in def_schema:
                enum_name = f"Defs{convert_to_camel_case(name)}"
                identity = ("definition", self.lexicon_id, name)
                self.enum_generator.generate_closed_string_enum(enum_name, def_schema['enum'], identity)
            elif def_type == "string" and 'knownValues' in def_schema:
                enum_name = f"{convert_to_camel_case(name)}"
                if enum_name not in self.generated_tokens:
                    known_values = def_schema['knownValues']
                    self.enum_generator.generate_enum_from_known_values(enum_name, known_values, self.token_descriptions)
            elif def_type == "union":
                # Named top-level union def (e.g. defs#signedTransition).
                # convert_ref resolves refs to these as the bare CamelCase def
                # name, so the enum must carry exactly that name.
                self.enum_generator.generate_enum_for_union_def(
                    name, def_schema.get('refs', []), closed=def_schema.get('closed', False),
                )
            elif def_type in ("string", "bytes", "integer", "boolean", "blob", "cid-link", "unknown", "array"):
                # Plain named non-object def. Local refs to blob/bytes/cid-link defs
                # are inlined by convert_ref; the typealias additionally satisfies
                # cross-lexicon refs (Container.Name) and refs to scalar and array
                # defs, which have no other Swift type.
                alias_name = convert_to_camel_case(name)
                swift_type = self.type_converter.determine_swift_type(
                    name, def_schema, [name], current_struct_name
                )
                self.enums += f"public typealias {alias_name} = {swift_type}\n\n"

        return self.template_manager.lex_definitions_template.render(
            lex_definitions=lex_definitions,
            lexicon_id=self.lexicon_id
        )

    def generate_token_constant(self, name: str, def_schema: Dict[str, Any]) -> None:
        """`public static let <name>` holding the token's fully-qualified value.

        A token has no data representation; it is referenced by the string
        `<nsid>#<name>` (in `knownValues`, for example). The constant gives that
        string a checked, discoverable name.
        """
        member = swift_member_name(name)
        if member in RESERVED_CONTAINER_MEMBERS or name == 'main':
            member = f"{member}Token"
        member = sanitize_swift_keyword(member)
        value = normalize_ref(f"#{name}", self.lexicon_id)
        description = def_schema.get('description', '')
        doc = self.template_manager.env.filters['escapeComment'](description)
        literal = self.template_manager.env.filters['escapeStringLiteral'](value)
        if doc:
            self.enums += f"/// {doc}\n"
        else:
            self.enums += f"/// The `{value}` token.\n"
        self.enums += f'public static let {member} = "{literal}"\n\n'

    def generate_record_struct(self):
        if 'record' not in self.main_def:
            return ""
        record_schema = self.main_def['record']
        current_struct_name = self.struct_name 
        properties = self.generate_properties(
            record_schema.get('properties', {}),
            record_schema.get('required', []),
            current_struct_name,
            nullable_fields=record_schema.get('nullable', []),
        )
        return self.template_manager.record_template.render(
            struct_name=self.struct_name,
            properties=properties,
            record_key_literal=json.dumps(self.main_def.get('key', 'any')),
            ctx=self.object_context(
                properties, encodes_type=True, value_semantics=True, lenient=True, extra_fields=True,
            ),
        )

    def generate_permission_set(self) -> str:
        """`static let permissionSet` describing a `permission-set` lexicon.

        Unknown resource types are kept as written; the permission specification
        tells consumers to ignore resources they do not recognise.
        """
        def literal(value):
            return json.dumps(value, ensure_ascii=False) if value is not None else "nil"

        def localized(prefix):
            entries = {
                key[len(prefix) + 1:]: value
                for key, value in sorted(self.main_def.items())
                if key.startswith(prefix + ":") and isinstance(value, str)
            }
            if not entries:
                return "[:]"
            return "[" + ", ".join(f"{literal(lang)}: {literal(text)}" for lang, text in entries.items()) + "]"

        permissions = []
        for permission in self.main_def.get('permissions', []):
            if not isinstance(permission, dict) or not isinstance(permission.get('resource'), str):
                continue
            parameters = {}
            for key, value in permission.items():
                if key in ('type', 'resource', 'inheritAud'):
                    continue
                if isinstance(value, list):
                    parameters[key] = [str(item) for item in value]
                elif isinstance(value, bool):
                    parameters[key] = ["true" if value else "false"]
                elif isinstance(value, (str, int)):
                    parameters[key] = [str(value)]
            parameter_literal = (
                "[" + ", ".join(
                    f"{literal(key)}: [{', '.join(literal(item) for item in values)}]"
                    for key, values in parameters.items()
                ) + "]"
            ) if parameters else "[:]"
            inherit = "true" if permission.get('inheritAud') is True else "false"
            permissions.append(
                f"            LexiconPermission(resource: {literal(permission['resource'])}, "
                f"parameters: {parameter_literal}, inheritAud: {inherit})"
            )
        permissions_literal = ("[\n" + ",\n".join(permissions) + "\n        ]") if permissions else "[]"
        nsid_literal = literal(self.lexicon_id)
        return f"""
    /// The permission set this lexicon declares. Request it as an OAuth scope with
    /// `permissionSet.includeScope(audience:)`.
    public static let permissionSet = LexiconPermissionSet(
        nsid: {nsid_literal},
        title: {literal(self.main_def.get('title'))},
        titleLang: {localized('title')},
        detail: {literal(self.main_def.get('detail'))},
        detailLang: {localized('detail')},
        permissions: {permissions_literal}
    )
"""

    def convert(self) -> str:
        # Security-bearing local output references must fail the generation
        # command instead of being serialized into a traceback-shaped source file.
        self.validate_output_local_refs()

        query_parameters = ""
        input_struct = ""
        output_struct = ""
        errors_enum = ""
        record_struct = ""
        main_properties = ""
        procedure = ""
        query = ""
        subscription = ""
        message_union = ""
        space_declaration = ""
        permission_set = ""
        server_contracts = ""
        conformance = ""

        main_def_type = self.main_def.get('type') if 'main' in self.defs else None
        if main_def_type == 'object':
            properties = self.generate_properties(
                self.main_def.get('properties', {}),
                self.main_def.get('required', []),
                convert_to_camel_case(self.lexicon_id),
                nullable_fields=self.main_def.get('nullable', []),
            )
            main_properties = self.template_manager.properties_template.render(
                properties=properties,
                ctx=self.object_context(
                    properties, encodes_type=False, value_semantics=True, lenient=False, extra_fields=True,
                ),
            )
            conformance = ": ATProtocolCodable, ATProtocolValue"
        elif main_def_type == 'record':
            record_struct = self.generate_record_struct()
            conformance = ": ATProtocolCodable, ATProtocolValue"
        elif main_def_type == 'space':
            space_declaration = self.generate_space_declaration(self.main_def)
        elif main_def_type == 'permission-set':
            permission_set = self.generate_permission_set()
        elif main_def_type == 'query':
            query_parameters = self.generate_query_parameters(self.main_def.get('parameters'))
            output_struct = self.generate_output_struct(self.main_def.get('output'))
            errors_enum = self.generate_errors_enum(self.main_def.get('errors'))
            query = self.generate_query_function(lexicon_id=self.lexicon_id, main_def=self.main_def)
        elif main_def_type == 'procedure':
            query_parameters = self.generate_query_parameters(self.main_def.get('parameters'))
            input_struct = self.generate_input_struct(self.main_def.get('input'))
            output_struct = self.generate_output_struct(self.main_def.get('output'))
            errors_enum = self.generate_errors_enum(self.main_def.get('errors'))
            procedure = self.generate_procedure_function(lexicon_id=self.lexicon_id, main_def=self.main_def)
        elif main_def_type == 'subscription':
            query_parameters = self.generate_query_parameters(self.main_def.get('parameters'))
            message_union = self.generate_message_union(self.main_def.get('message'))
            errors_enum = self.generate_errors_enum(self.main_def.get('errors'))
            subscription = self.generate_subscription_function(lexicon_id=self.lexicon_id, main_def=self.main_def)
        if self.emit_server_contracts and main_def_type in ('query', 'procedure', 'subscription'):
            server_contracts = self.generate_server_contracts(main_def_type)

        # Named definitions are generated whatever `main` is (or is not): a lexicon
        # whose main is a token, string, array or permission set still owns its
        # sibling defs.
        lex_definitions = self.generate_lex_definitions()

        unused_overrides = set(self.property_type_overrides) - self.used_property_type_overrides
        if unused_overrides:
            raise ValueError(
                f"{self.lexicon_id}: property_type_overrides entries match no generated property: "
                f"{sorted(unused_overrides)}"
            )

        swift_code = self.template_manager.main_template.render(
            enums=self.enums,
            lexicon_version=self.lexicon_version,
            lexicon_id=self.lexicon_id,
            description=self.description,
            struct_name=self.struct_name,
            query_parameters=query_parameters,
            input_struct=input_struct,
            output_struct=output_struct,
            errors_enum=errors_enum,
            lex_definitions=lex_definitions,
            record_struct=record_struct,
            main_properties=main_properties,
            procedure=procedure,
            query=query,
            subscription=subscription,
            message_union=message_union,
            space_declaration=space_declaration,
            permission_set=permission_set,
            server_contracts=server_contracts,
            conformance=conformance
        )

        return self.post_process_swift_code(swift_code)

    def generate_space_declaration(self, main_def):
        key_type = main_def.get('key', 'tid')
        title = json.dumps(main_def['title']) if isinstance(main_def.get('title'), str) else 'nil'
        title_lang = main_def.get('title:lang', {})
        if not isinstance(title_lang, dict):
            title_lang = {}
        title_lang_literal = ', '.join(
            f'{json.dumps(language)}: {json.dumps(value)}'
            for language, value in sorted(title_lang.items())
            if isinstance(language, str) and isinstance(value, str)
        )
        title_lang_expression = f'[{title_lang_literal}]' if title_lang_literal else '[:]'
        collections = main_def.get('collections', [])
        collections_literal = ', '.join(json.dumps(value) for value in collections)
        return f'''\n    public struct SpaceDeclarationDescriptor: Sendable, Equatable {{
        public let nsid: String
        public let keyType: String
        public let title: String?
        public let titleLang: [String: String]
        public let collections: [String]
    }}

    public static let spaceDeclaration = SpaceDeclarationDescriptor(
        nsid: "{self.lexicon_id}", keyType: {json.dumps(key_type)},
        title: {title}, titleLang: {title_lang_expression},
        collections: [{collections_literal}]
    )
'''

    def generate_server_contracts(self, main_def_type):
        parameters_type = 'Parameters' if 'parameters' in self.main_def else 'Void'
        input_type = 'Input' if main_def_type == 'procedure' and 'input' in self.main_def else 'Void'
        if main_def_type == 'subscription':
            output_type = 'Message'
        else:
            output_type = 'Output' if 'output' in self.main_def else 'Void'
        input_encoding = self.main_def.get('input', {}).get('encoding')
        output_encoding = self.main_def.get('output', {}).get('encoding')
        input_encoding_literal = json.dumps(input_encoding) if input_encoding is not None else 'nil'
        output_encoding_literal = json.dumps(output_encoding) if output_encoding is not None else 'nil'
        return f'''\n    public struct XRPCMethodDescriptor: Sendable, Equatable {{
        public let nsid: String
        public let kind: String
        public let inputEncoding: String?
        public let outputEncoding: String?
        public let declaredErrors: [String]
    }}

    public static let endpointDescriptor = XRPCMethodDescriptor(
        nsid: "{self.lexicon_id}", kind: "{main_def_type}",
        inputEncoding: {input_encoding_literal}, outputEncoding: {output_encoding_literal},
        declaredErrors: [{', '.join(json.dumps(error.get('name', '')) for error in self.main_def.get('errors', []))}]
    )

    public protocol ServerHandler: Sendable {{
        associatedtype Context: Sendable
        func handle(
            parameters: {parameters_type}, input: {input_type}, context: Context
        ) async throws -> {output_type}
    }}
'''

    _GLUED_DECLARATION = re.compile(r'(?<=[^\s/])[ \t]*(public (?:indirect )?(?:struct|enum) )')

    @staticmethod
    def post_process_swift_code(code: str) -> str:
        # Template whitespace control can leave a type declaration on the same line
        # as the token before it (`}public enum Error`); give it its own line. A
        # declaration that already starts a line is left alone, so its `///` block
        # stays attached (SwiftFormat demotes a detached one to a plain comment).
        # Blank lines between declarations are SwiftFormat's job.
        lines = []
        for line in code.lstrip().split('\n'):
            if line.lstrip().startswith('//'):
                lines.append(line)
            else:
                lines.append(SwiftCodeGenerator._GLUED_DECLARATION.sub(r'\n\1', line))
        return '\n'.join(lines)

    def generate_query_function(self, lexicon_id, main_def):
        # Split the lexicon ID to determine the namespace
        template_namespace_name = namespace_type_path(lexicon_id)
        
        # Determine the query name by converting the last part of the lexicon ID to CamelCase
        query_name = convert_to_camel_case(lexicon_id.split('.')[-1])
                
        # Determine if the query has input parameters
        has_input = 'parameters' in main_def
        input_struct_name = convert_to_camel_case(lexicon_id) + ".Parameters" if has_input else None
        output_type = convert_to_camel_case(lexicon_id) + ".Output" if 'output' in main_def else None
        
        input_parameters = ''
        input_values = ''

        # Define the API endpoint
        endpoint = f"{lexicon_id}"
        
        # Extract the output encoding, defaulting to 'application/json' if not specified
        output_encoding = main_def.get('output', {}).get('encoding', 'application/json')
        
        # Render the query template with the encoding information
        return self.template_manager.query_template.render(
            pagination=self.pagination_conformances(main_def, output_encoding),
            template_namespace_name=template_namespace_name,
            query_name=query_name,
            input_parameters=input_parameters,
            input_struct_name=input_struct_name,
            input_values=input_values,
            output_type=output_type,
            endpoint=endpoint,
            description=self.description,
            output_encoding=output_encoding,  # Pass the output encoding to the template
            has_errors=bool(main_def.get('errors')),
            struct_name=self.struct_name,
            emit_xrpc_error_parsing=self.emit_xrpc_error_parsing,
        )

    def pagination_conformances(self, main_def, output_encoding) -> str:
        """XRPCPages conformances for a query that pages with a `cursor`.

        The query must take an optional plain-string `cursor` parameter and return
        an object whose optional `cursor` is a plain string. Everything else
        (a typed cursor, an output that is a ref to a shared def) is left alone.
        """
        if output_encoding != 'application/json':
            return ""
        cursor_param = next((p for p in self.parameter_properties if p['name'] == 'cursor'), None)
        if cursor_param is None or cursor_param['type'] != 'String' or not cursor_param['wire_optional']:
            return ""
        schema = main_def.get('output', {}).get('schema', {})
        if schema.get('type') != 'object':
            return ""
        cursor_schema = schema.get('properties', {}).get('cursor')
        if (
            not isinstance(cursor_schema, dict)
            or cursor_schema.get('type') != 'string'
            or 'format' in cursor_schema
            or 'enum' in cursor_schema
            or 'knownValues' in cursor_schema
            or 'cursor' in schema.get('required', [])
            or 'cursor' in schema.get('nullable', [])
        ):
            return ""
        arguments = ', '.join(
            f"{p['ident']}: {'cursor' if p['name'] == 'cursor' else p['ident']}"
            for p in self.parameter_properties
        )
        return (
            f"extension {self.struct_name}.Parameters: XRPCCursorPaginatedParameters {{\n"
            f"    public func withCursor(_ cursor: String?) -> Self {{\n"
            f"        Self({arguments})\n"
            f"    }}\n"
            f"}}\n\n"
            f"extension {self.struct_name}.Output: XRPCCursorPaginatedOutput {{}}\n"
        )

    def generate_procedure_function(self, lexicon_id, main_def):
        # Split the lexicon ID to determine the namespace
        template_namespace_name = namespace_type_path(lexicon_id)

        # Determine the procedure name by converting the last part of the lexicon ID to CamelCase
        procedure_name = convert_to_camel_case(lexicon_id.split('.')[-1])

        # Determine if the procedure is a blob upload based on the input encoding
        input_encoding = main_def.get('input', {}).get('encoding', '') if 'input' in main_def else None
        is_blob_upload = 'input' in main_def and input_encoding == '*/*'
        is_binary_data = 'input' in main_def and input_encoding != '' and input_encoding != 'application/json' and input_encoding != '*/*'

        input_parameters = ''
        input_values = ''
        input_struct_name = None

        # Extract input and output encodings, defaulting to 'application/json' if not specified
        input_encoding = main_def.get('input', {}).get('encoding', 'application/json') if 'input' in main_def else None
        output_encoding = main_def.get('output', {}).get('encoding', 'application/json') if 'output' in main_def else None

        if 'input' in main_def and 'schema' in main_def['input']:
            input_params = main_def['input']['schema'].get('properties', {})
            generated_types = {prop['name']: prop['type'] for prop in self.input_properties}
            input_parameters = ', '.join([
                f"{param}: {generated_types[param]}"
                for param, details in input_params.items()
            ])
            input_values = ', '.join([f"{param}: {param}" for param in input_params.keys()])
            input_struct_name = convert_to_camel_case(lexicon_id) + ".Input"

        # Determine if the procedure has query parameters (like queries do)
        has_parameters = 'parameters' in main_def
        parameters_struct_name = convert_to_camel_case(lexicon_id) + ".Parameters" if has_parameters else None

        # Define the API endpoint
        endpoint = f"{lexicon_id}"

        # Render the procedure template with the encoding information
        return self.template_manager.procedure_template.render(
            template_namespace_name=template_namespace_name,
            procedure_name=procedure_name,
            input_parameters=input_parameters,
            input_struct_name=input_struct_name,
            input_values=input_values,
            output_type=convert_to_camel_case(lexicon_id) + ".Output" if 'output' in main_def else None,
            endpoint=endpoint,
            description=self.description,
            is_blob_upload=is_blob_upload,
            is_binary_data=is_binary_data,
            input_encoding=input_encoding,    # Pass the input encoding to the template
            output_encoding=output_encoding,  # Pass the output encoding to the template
            has_parameters=has_parameters,
            parameters_struct_name=parameters_struct_name,
            has_errors=bool(main_def.get('errors')),
            struct_name=self.struct_name,
            emit_xrpc_error_parsing=self.emit_xrpc_error_parsing,
        )

    def generate_subscription_function(self, lexicon_id, main_def):
        # Split the lexicon ID to determine the namespace
        template_namespace_name = namespace_type_path(lexicon_id)
        
        # Determine the subscription name by converting the last part of the lexicon ID to camelCase
        subscription_name = convert_to_camel_case(lexicon_id.split('.')[-1])
        # Make first letter lowercase for method name
        subscription_name = subscription_name[0].lower() + subscription_name[1:] if subscription_name else subscription_name
        
        # Determine if the subscription has input parameters
        has_parameters = 'parameters' in main_def
        input_struct_name = convert_to_camel_case(lexicon_id) + ".Parameters" if has_parameters else None

        # Get the message type - for SSE streams, use Output instead of Message
        if 'output' in main_def:
            # SSE stream (query with text/event-stream encoding)
            message_type = convert_to_camel_case(lexicon_id) + ".Output"
        else:
            # Traditional subscription (WebSocket)
            message_type = convert_to_camel_case(lexicon_id) + ".Message"
        
        input_parameters = ''
        input_values = ''
        
        if has_parameters:
            # The convenience signature repeats the `Parameters` initializer, so it
            # uses the very types generated for that struct (an inline enum, for one,
            # is named after `Parameters`, not after the parameter).
            param_list = []
            value_list = []
            for prop in self.parameter_properties:
                swift_type = prop['type']
                leaf = swift_type.strip('[]')
                if leaf in self.closed_enum_identity_by_name:
                    # The method lives in an extension outside the lexicon container.
                    swift_type = swift_type.replace(leaf, f"{self.struct_name}.{leaf}")
                default = prop.get('default_literal')
                if prop['optional']:
                    param_list.append(f"{prop['ident']}: {swift_type}? = {default or 'nil'}")
                elif default:
                    param_list.append(f"{prop['ident']}: {swift_type} = {default}")
                else:
                    param_list.append(f"{prop['ident']}: {swift_type}")
                value_list.append(f"{prop['ident']}: {prop['ident']}")

            input_parameters = ', '.join(param_list)
            input_values = ', '.join(value_list)

        # Define the API endpoint
        endpoint = f"{lexicon_id}"
        
        # Render the subscription template
        return self.template_manager.subscription_template.render(
            template_namespace_name=template_namespace_name,
            subscription_name=subscription_name,
            has_parameters=has_parameters,
            input_parameters=input_parameters,
            input_struct_name=input_struct_name,
            input_values=input_values,
            message_type=message_type,
            endpoint=endpoint,
            description=self.description
        )

def convert_json_to_swift(json_content: str) -> str:
    lexicon = json.loads(json_content)
    generator = SwiftCodeGenerator(lexicon)
    return generator.convert()
