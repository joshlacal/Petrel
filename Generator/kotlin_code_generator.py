"""
Kotlin code generator - generates Kotlin code from AT Protocol lexicons.
"""
from typing import Dict, List, Any, Optional
from base_code_generator import BaseCodeGenerator
from kotlin_type_converter import KotlinTypeConverter, convert_to_pascal_case
from kotlin_enum_generator import KotlinEnumGenerator
from kotlin_templates import KotlinTemplateManager


class KotlinCodeGenerator(BaseCodeGenerator):
    """Generates Kotlin code from lexicons."""

    def __init__(self, lexicon: Dict[str, Any], cycle_detector=None, overlay=False):
        self.overlay = overlay
        super().__init__(lexicon, cycle_detector)

        self.class_name = convert_to_pascal_case(self.lexicon_id)
        self.object_name = self.class_name + "Defs"
        self.sealed_interfaces = ""
        self.enum_classes = ""

        self.template_manager = KotlinTemplateManager()
        self.type_converter = KotlinTypeConverter(self)
        self.enum_generator = KotlinEnumGenerator(self)

    def get_file_extension(self) -> str:
        """Return .kt for Kotlin files."""
        return '.kt'

    def convert(self) -> str:
        """Generate Kotlin code for the lexicon."""
        try:
            main_def_type = self.main_def.get('type', '')

            # Initialize components
            query_code = ""
            procedure_code = ""
            subscription_code = ""
            parameters_code = ""
            input_code = ""
            output_code = ""
            message_code = ""
            errors_code = ""
            record_code = ""
            lex_definitions_code = ""
            main_properties_code = ""

            # Generate based on lexicon type
            if not self.main_def:
                # Definitions-only file
                lex_definitions_code = self.generate_lex_definitions()
            elif main_def_type == 'object':
                lex_definitions_code = self.generate_lex_definitions()
                main_properties_code = self.generate_main_properties()
            elif main_def_type == 'record':
                record_code = self.generate_record()
                lex_definitions_code = self.generate_lex_definitions()
            elif main_def_type == 'query':
                parameters_code = self.generate_parameters(self.main_def.get('parameters'))
                output_code = self.generate_output(self.main_def.get('output'))
                errors_code = self.generate_errors(self.main_def.get('errors'))
                lex_definitions_code = self.generate_lex_definitions()
                query_code = self.generate_query_function()
            elif main_def_type == 'procedure':
                parameters_code = self.generate_parameters(self.main_def.get('parameters'))
                input_code = self.generate_input(self.main_def.get('input'))
                output_code = self.generate_output(self.main_def.get('output'))
                errors_code = self.generate_errors(self.main_def.get('errors'))
                lex_definitions_code = self.generate_lex_definitions()
                procedure_code = self.generate_procedure_function()
            elif main_def_type == 'subscription':
                parameters_code = self.generate_parameters(self.main_def.get('parameters'))
                message_code = self.generate_message(self.main_def.get('message'))
                errors_code = self.generate_errors(self.main_def.get('errors'))
                lex_definitions_code = self.generate_lex_definitions()
                subscription_code = self.generate_subscription_function()

            # Process all union types
            self.generate_all_unions()

            # Render main template
            kotlin_code = self.template_manager.main_template.render(
                lexicon_id=self.lexicon_id,
                lexicon_version=self.lexicon_version,
                description=self.description,
                class_name=self.class_name,
                object_name=self.object_name,
                sealed_interfaces=self.sealed_interfaces,
                enum_classes=self.enum_classes,
                lex_definitions=lex_definitions_code,
                record=record_code,
                main_properties=main_properties_code,
                parameters=parameters_code,
                input=input_code,
                output=output_code,
                message=message_code,
                errors=errors_code,
                query=query_code,
                procedure=procedure_code,
                subscription=subscription_code
            )

            return self.post_process_kotlin_code(kotlin_code)

        except Exception as e:
            import traceback
            return f"// Error generating Kotlin code: {str(e)}\n// {traceback.format_exc()}"

    def generate_properties(self, properties: Dict[str, Any], required_fields: List[str],
                           current_struct_name: str) -> List[Dict[str, Any]]:
        """Generate property definitions."""
        kotlin_properties = []

        for name, prop in properties.items():
            kotlin_type = self.type_converter.determine_type(name, prop, required_fields, current_struct_name)
            description = prop.get('description', '')
            is_optional = name not in required_fields

            kotlin_properties.append({
                'name': name,
                'type': kotlin_type,
                'optional': is_optional,
                'description': description
            })

        return kotlin_properties

    def generate_main_properties(self) -> str:
        """Generate properties for main object type."""
        properties = self.main_def.get('properties', {})
        required = self.main_def.get('required', [])

        props = self.generate_properties(properties, required, self.class_name)

        return self.template_manager.properties_template.render(
            properties=props,
            class_name=self.class_name
        )

    def generate_lex_definitions(self) -> str:
        """Generate nested type definitions."""
        definitions = []

        for name, def_schema in self.defs.items():
            if name == 'main':
                continue

            def_type = def_schema.get('type', '')
            class_name = self.class_name + convert_to_pascal_case(name)
            print(f"Processing def: {name}, type: {def_type}")

            if def_type == 'object':
                properties = self.generate_properties(
                    def_schema.get('properties', {}),
                    def_schema.get('required', []),
                    class_name
                )
                definitions.append({
                    'name': class_name,
                    'type': 'data_class',
                    'properties': properties,
                    'description': def_schema.get('description', '')
                })

            elif def_type == 'string' and 'knownValues' in def_schema:
                print(f"Generating enum for {name}")
                # Generate enum class
                known_values = def_schema['knownValues']
                self.enum_generator.generate_enum_class_from_known_values(class_name, known_values)

            elif def_type == 'array':
                # Generate type alias for array
                item_type = self.type_converter._get_array_item_type(def_schema, name, class_name)
                definitions.append({
                    'name': class_name,
                    'type': 'type_alias',
                    'target': f"List<{item_type}>",
                    'description': def_schema.get('description', '')
                })
                
                # Also handle union items if present
                if def_schema.get('items', {}).get('type') == 'union':
                    raw_refs = def_schema['items'].get('refs', [])
                    converted_refs = [self.type_converter.convert_ref(r) for r in raw_refs]
                    self.enum_generator.generate_sealed_interface_for_union_array(self.class_name, name, converted_refs, raw_refs=raw_refs)

            elif def_type == 'array' and def_schema.get('items', {}).get('type') == 'union':
                # This block is now redundant or covered above
                pass

        return self.template_manager.lex_definitions_template.render(
            definitions=definitions
        )

    def generate_record(self) -> str:
        """Generate a record type (data class)."""
        if 'record' not in self.main_def:
            return ""

        record_schema = self.main_def['record']
        properties = self.generate_properties(
            record_schema.get('properties', {}),
            record_schema.get('required', []),
            self.class_name
        )

        return self.template_manager.record_template.render(
            class_name=self.class_name,
            properties=properties,
            description=self.description
        )

    def generate_parameters(self, parameters: Optional[Dict[str, Any]]) -> str:
        """Generate query parameters data class."""
        if not parameters:
            return ""

        properties = self.generate_properties(
            parameters.get('properties', {}),
            parameters.get('required', []),
            self.class_name + "Parameters"
        )

        return self.template_manager.parameters_template.render(
            properties=properties,
            class_name=self.class_name
        )

    def generate_input(self, input_obj: Optional[Dict[str, Any]]) -> str:
        """Generate input data class for procedures."""
        if not input_obj:
            return ""

        encoding = input_obj.get('encoding', '')

        # Handle binary data inputs
        if 'schema' not in input_obj:
            if encoding and encoding != 'application/json':
                properties = [{'name': 'data', 'type': 'ByteArray', 'optional': False, 'description': ''}]
                return self.template_manager.input_template.render(properties=properties, class_name=self.class_name)
            return ""

        input_schema = input_obj['schema']

        # Handle ref type
        if input_schema.get('type') == 'ref':
            ref_type = self.type_converter.convert_ref(input_schema['ref'])
            properties = [{'name': 'data', 'type': ref_type, 'optional': False, 'description': ''}]
        # Handle binary encoding
        elif encoding and encoding not in ['', 'application/json']:
            properties = [{'name': 'data', 'type': 'ByteArray', 'optional': False, 'description': ''}]
        else:
            properties = self.generate_properties(
                input_schema.get('properties', {}),
                input_schema.get('required', []),
                self.class_name + "Input"
            )

        return self.template_manager.input_template.render(
            properties=properties,
            class_name=self.class_name
        )

    def generate_output(self, output_obj: Optional[Dict[str, Any]]) -> str:
        """Generate output data class."""
        if not output_obj:
            return ""

        encoding = output_obj.get('encoding', '')
        output_schema = output_obj.get('schema', {})

        # Handle type alias
        if output_schema.get('type') == 'ref':
            ref_type = self.type_converter.convert_ref(output_schema['ref'])
            return self.template_manager.output_template.render(
                is_type_alias=True,
                type_alias_target=ref_type,
                properties=[],
                class_name=self.class_name
            )

        # Handle binary output
        if encoding == '*/*' or (encoding and encoding != 'application/json' and not output_schema.get('properties')):
            properties = [{'name': 'data', 'type': 'ByteArray', 'optional': False, 'description': ''}]
        elif output_schema.get('properties'):
            properties = self.generate_properties(
                output_schema.get('properties', {}),
                output_schema.get('required', []),
                self.class_name + "Output"
            )
        else:
            properties = []

        return self.template_manager.output_template.render(
            is_type_alias=False,
            type_alias_target=None,
            properties=properties,
            class_name=self.class_name
        )

    def generate_message(self, message_obj: Optional[Dict[str, Any]]) -> str:
        """Generate message data class (or register a union sealed interface) for subscriptions."""
        if not message_obj:
            return ""

        schema = message_obj.get('schema', {})
        schema_type = schema.get('type', '')

        if schema_type == 'union':
            # For union messages the "type" is a sealed interface that the enum
            # generator emits into self.sealed_interfaces. We still render an
            # (empty) Message placeholder so the main template's {% if message %}
            # block keeps emitting something familiar, but the real flow element
            # type is the union — tracked via self.subscription_message_union.
            #
            # Filter out refs that resolve to non-object lexicon defs (e.g.
            # `type: "bytes"` targets like `place.stream.live.subscribeSegments`'s
            # `#segment`). The codegen doesn't emit data classes for those, so
            # including them as sealed-interface variants produces an
            # unresolved-type compile error. They're surfaced via the synthetic
            # `Unexpected` variant at runtime until the generator grows
            # primitive-ref support (see subscription.jinja).
            raw_refs = schema.get('refs', [])
            filtered_raw_refs = [
                r for r in raw_refs
                if self._resolve_ref_def_type(r) in ('object', None)
            ]
            refs = [self.type_converter.convert_ref(r) for r in filtered_raw_refs]
            self.enum_generator.generate_sealed_interface_for_union(
                self.class_name, "Message", refs, raw_refs=filtered_raw_refs
            )
            # Empty Message class is still rendered so existing callers that
            # reference <Class>Message by name don't break. The real element
            # type is <Class>MessageUnion.
            return self.template_manager.message_template.render(
                properties=[],
                class_name=self.class_name
            )

        properties = self.generate_properties(
            schema.get('properties', {}),
            schema.get('required', []),
            self.class_name + "Message"
        )

        return self.template_manager.message_template.render(
            properties=properties,
            class_name=self.class_name
        )

    def generate_errors(self, errors: Optional[List[Dict[str, str]]]) -> str:
        """Generate error sealed class."""
        if not errors:
            return ""

        return self.template_manager.errors_enum_template.render(
            errors=errors,
            class_name=self.class_name
        )


    def _receiver_type(self, namespace_parts):
        """Extension receiver for endpoint functions.

        Core: nested inner classes on the client (ATProtoClient.Chat.Bsky.Convo).
        Overlay: standalone namespace classes generated alongside this package
        (BlueCatbirdMlsChatNamespace), since Kotlin cannot add nested classes
        to another module's type.
        """
        if self.overlay:
            return ''.join(convert_to_pascal_case(p) for p in namespace_parts) + 'Namespace'
        return 'ATProtoClient.' + '.'.join(convert_to_pascal_case(p) for p in namespace_parts)

    def generate_query_function(self) -> str:
        """Generate suspend function for query endpoint."""
        # Determine namespace
        parts = self.lexicon_id.split('.')
        namespace_parts = parts[:-1]
        function_name = self._to_camel_case(parts[-1])

        # Build namespace path
        namespace_path = '.'.join(convert_to_pascal_case(p) for p in namespace_parts)

        # Determine types
        has_parameters = 'parameters' in self.main_def
        parameters_type = f"{self.class_name}Parameters" if has_parameters else None
        output_type = f"{self.class_name}Output" if 'output' in self.main_def else None

        # Get encoding
        output_encoding = self.main_def.get('output', {}).get('encoding', 'application/json')

        return self.template_manager.query_template.render(
            receiver_type=self._receiver_type(namespace_parts),
            function_name=function_name,
            has_parameters=has_parameters,
            parameters_type=parameters_type,
            output_type=output_type,
            endpoint=self.lexicon_id,
            description=self.description,
            output_encoding=output_encoding
        )

    def generate_procedure_function(self) -> str:
        """Generate suspend function for procedure endpoint."""
        parts = self.lexicon_id.split('.')
        namespace_parts = parts[:-1]
        function_name = self._to_camel_case(parts[-1])

        namespace_path = '.'.join(convert_to_pascal_case(p) for p in namespace_parts)

        has_input = 'input' in self.main_def
        input_type = f"{self.class_name}Input" if has_input else None
        output_type = f"{self.class_name}Output" if 'output' in self.main_def else None

        input_encoding = self.main_def.get('input', {}).get('encoding', 'application/json') if has_input else None
        output_encoding = self.main_def.get('output', {}).get('encoding', 'application/json') if 'output' in self.main_def else None

        is_blob_upload = self.is_blob_upload()
        is_binary_data = has_input and input_encoding and input_encoding not in ['', 'application/json', '*/*']

        has_parameters = 'parameters' in self.main_def
        parameters_type = f"{self.class_name}Parameters" if has_parameters else None

        return self.template_manager.procedure_template.render(
            receiver_type=self._receiver_type(namespace_parts),
            function_name=function_name,
            has_input=has_input,
            has_parameters=has_parameters,
            parameters_type=parameters_type,
            input_type=input_type,
            output_type=output_type,
            endpoint=self.lexicon_id,
            description=self.description,
            is_blob_upload=is_blob_upload,
            is_binary_data=is_binary_data,
            input_encoding=input_encoding,
            output_encoding=output_encoding
        )

    def generate_subscription_function(self) -> str:
        """Generate Flow function for subscription endpoint."""
        parts = self.lexicon_id.split('.')
        namespace_parts = parts[:-1]
        function_name = self._to_camel_case(parts[-1])

        namespace_path = '.'.join(convert_to_pascal_case(p) for p in namespace_parts)

        has_parameters = 'parameters' in self.main_def
        parameters_type = f"{self.class_name}Parameters" if has_parameters else None

        message_schema = self.main_def.get('message', {}).get('schema', {}) or {}
        is_union = message_schema.get('type') == 'union'

        # When the schema is a union, the Flow element is the generated sealed
        # interface <Class>MessageUnion. Otherwise fall back to the (often empty)
        # <Class>Message data class so the emitted file compiles.
        message_union = f"{self.class_name}MessageUnion"
        message_type = message_union if is_union else f"{self.class_name}Message"

        # Build variant metadata for the CBOR header dispatch. Each ref becomes
        # a `when (header.t)` branch that decodes the payload into the matching
        # sealed-interface variant. Non-object refs (e.g. `type: bytes` targets)
        # resolve to a variant whose payload type isn't a @Serializable data
        # class — we fall through to Unexpected for those by omitting them from
        # variants (and a comment is emitted in the template).
        variants = []
        if is_union:
            raw_refs = message_schema.get('refs', [])
            short_names_seen = set()
            for raw_ref in raw_refs:
                if '#' in raw_ref:
                    base, fragment = raw_ref.split('#', 1)
                    short_name = convert_to_pascal_case(fragment)
                    header_tag = f"#{fragment}"
                else:
                    parts_ref = raw_ref.split('.')
                    short_name = convert_to_pascal_case(parts_ref[-1])
                    header_tag = raw_ref

                # Dedupe short names by falling back to the full type name
                variant_type = self.type_converter.convert_ref(raw_ref)
                if short_name in short_names_seen:
                    short_name = variant_type
                short_names_seen.add(short_name)

                # Skip refs whose target isn't an object (no @Serializable class
                # available). The sealed-interface generator already includes
                # them as variants, but the CBOR dispatch can't decode them
                # generically — leave them to the Unexpected branch.
                target_def = self._resolve_ref_def_type(raw_ref)
                if target_def not in ('object', None):
                    # Still include the variant (sealed interface carries it)
                    # but flag it so the template knows to skip decoding.
                    variants.append({
                        'header_tag': header_tag,
                        'short_name': short_name,
                        'payload_type': variant_type,
                        'decodable': False,
                    })
                else:
                    variants.append({
                        'header_tag': header_tag,
                        'short_name': short_name,
                        'payload_type': variant_type,
                        'decodable': True,
                    })

        return self.template_manager.subscription_template.render(
            receiver_type=self._receiver_type(namespace_parts),
            function_name=function_name,
            has_parameters=has_parameters,
            parameters_type=parameters_type,
            message_type=message_type,
            message_union=message_union,
            is_union=is_union,
            variants=variants,
            endpoint=self.lexicon_id,
            description=self.description
        )

    def _resolve_ref_def_type(self, ref: str) -> Optional[str]:
        """Return the lexicon def `type` for a ref, or None if unresolved."""
        if ref.startswith('#'):
            # Local ref — look up in self.defs
            name = ref[1:]
            target = self.defs.get(name)
            if isinstance(target, dict):
                return target.get('type')
        # External refs aren't resolved here; assume object.
        return 'object'

    def generate_all_unions(self):
        """Process all union types in the lexicon."""
        main_def = self.main_def
        if not main_def:
            return

        properties = main_def.get('properties', {})
        for prop_name, prop_schema in properties.items():
            if prop_schema.get('type') == 'union':
                raw_refs = prop_schema.get('refs', [])
                refs = [self.type_converter.convert_ref(r) for r in raw_refs]
                self.enum_generator.generate_sealed_interface_for_union(self.class_name, prop_name, refs, raw_refs=raw_refs)
            elif prop_schema.get('type') == 'array':
                item_schema = prop_schema.get('items', {})
                if item_schema.get('type') == 'union':
                    raw_refs = item_schema.get('refs', [])
                    refs = [self.type_converter.convert_ref(r) for r in raw_refs]
                    self.enum_generator.generate_sealed_interface_for_union_array(self.class_name, prop_name, refs, raw_refs=raw_refs)

    def _to_camel_case(self, s: str) -> str:
        """Convert to camelCase."""
        pascal = convert_to_pascal_case(s)
        if not pascal:
            return pascal
        return pascal[0].lower() + pascal[1:]

    @staticmethod
    def post_process_kotlin_code(code: str) -> str:
        """Post-process generated Kotlin code."""
        # Remove excessive blank lines
        lines = code.split('\n')
        processed = []
        prev_blank = False

        for line in lines:
            is_blank = not line.strip()
            if is_blank and prev_blank:
                continue
            processed.append(line)
            prev_blank = is_blank

        return '\n'.join(processed)
