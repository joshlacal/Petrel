"""
Kotlin enum generator - generates sealed interfaces and enum classes.
"""
from typing import List
from kotlin_type_converter import convert_to_pascal_case


class KotlinEnumGenerator:
    """Generates Kotlin sealed interfaces for unions and enum classes for known values."""

    def __init__(self, code_generator):
        self.code_generator = code_generator
        self.generated_sealed_interfaces = set()
        self.generated_enum_classes = set()
        self.closed_enums_by_identity = {}
        self.closed_enum_identity_by_name = {}

    def generate_sealed_interface_for_union(self, current_struct_name: str, prop_name: str, refs: List[str], raw_refs: List[str] = None):
        """Generate a sealed interface for a union type property."""
        union_name = f"{current_struct_name}{convert_to_pascal_case(prop_name)}Union"
        print(f"Generating union: {union_name}", flush=True)

        if union_name in self.generated_sealed_interfaces:
            print(f"Skipping union {union_name}, already generated", flush=True)
            return

        self.generated_sealed_interfaces.add(union_name)

        # Build variant cases with both short and full names
        variants = []
        short_names_seen = set()
        for i, ref in enumerate(refs):
            raw_ref = raw_refs[i] if raw_refs and i < len(raw_refs) else ref
            short_name = self._get_short_variant_name(raw_ref)
            full_name = ref  # refs are already converted to full PascalCase names
            resolved_type = ref  # Already converted
            # Deduplicate short names by falling back to full name
            if short_name in short_names_seen:
                short_name = full_name
            short_names_seen.add(short_name)
            variants.append({
                'short_name': short_name,
                'full_name': full_name,
                'name': full_name,  # Use full name as the actual class name
                'type': resolved_type,
                'lexicon_ref': self._get_lexicon_ref(raw_ref)
            })

        # Render the sealed interface
        template = self.code_generator.template_manager.sealed_interface_template
        sealed_code = template.render(
            union_name=union_name,
            variants=variants,
            lexicon_id=self.code_generator.lexicon_id
        )

        self.code_generator.sealed_interfaces += sealed_code + '\n\n'

    def _get_short_variant_name(self, ref: str) -> str:
        """Get a short variant name from a reference (fragment only)."""
        if '#' in ref:
            _, fragment = ref.split('#')
            return convert_to_pascal_case(fragment)
        else:
            parts = ref.split('.')
            return convert_to_pascal_case(parts[-1])

    def _get_full_variant_name(self, ref: str) -> str:
        """Get the full variant name from a reference (includes namespace)."""
        if '#' in ref:
            base, fragment = ref.split('#')
            return convert_to_pascal_case(base) + convert_to_pascal_case(fragment)
        else:
            return convert_to_pascal_case(ref)

    def _get_unique_variant_name(self, ref: str) -> str:
        """Get a unique variant name from a reference (uses short name)."""
        return self._get_short_variant_name(ref)

    def generate_sealed_interface_for_union_array(self, current_struct_name: str, prop_name: str, refs: List[str], raw_refs: List[str] = None):
        """Generate a sealed interface for an array of unions."""
        # Same as regular union for Kotlin
        self.generate_sealed_interface_for_union(current_struct_name, prop_name, refs, raw_refs=raw_refs)

    def generate_enum_class_from_known_values(self, enum_name: str, known_values: List[str], descriptions: dict = None):
        """Generate an enum class from known values."""
        print(f"Generating enum class {enum_name} with values: {known_values}", flush=True)
        if enum_name in self.generated_enum_classes:
            print(f"Skipping {enum_name}, already generated", flush=True)
            return

        self.generated_enum_classes.add(enum_name)

        # Sanitize enum constant names
        constants = []
        print("Starting loop", flush=True)
        for value in known_values:
            print(f"Looping value: {value}", flush=True)
            # Convert to valid Kotlin enum constant name
            constant_name = self._sanitize_enum_constant(value)
            constants.append({
                'name': constant_name,
                'value': value,
                'description': descriptions.get(value, '') if descriptions else ''
            })

        # Render the enum class
        template = self.code_generator.template_manager.enum_class_template
        enum_code = template.render(
            enum_name=enum_name,
            constants=constants
        )

        self.code_generator.enum_classes += enum_code + '\n\n'

    @staticmethod
    def _closed_case_identifier(value: str) -> str:
        encoded = ''.join(
            char if char.isascii() and char.isalnum() else f'_u{ord(char):x}_'
            for char in value
        )
        return f"value_{encoded}"

    @staticmethod
    def _kotlin_string_literal(value: str) -> str:
        escapes = {
            '\\': '\\\\',
            '"': '\\"',
            '$': '\\$',
            '\n': '\\n',
            '\r': '\\r',
            '\t': '\\t',
            '\b': '\\b',
        }
        encoded = []
        for char in value:
            if char in escapes:
                encoded.append(escapes[char])
            elif ord(char) < 0x20 or ord(char) == 0x7f or char in ('\u2028', '\u2029'):
                encoded.append(f"\\u{ord(char):04x}")
            else:
                encoded.append(char)
        return f'"{"".join(encoded)}"'

    def generate_closed_string_enum(self, enum_name: str, values: List[str], identity):
        if not isinstance(values, list) or not all(isinstance(value, str) for value in values):
            raise ValueError(f"closed enum '{enum_name}' values must be a list of strings")
        if len(values) != len(set(values)):
            raise ValueError(f"closed enum '{enum_name}' contains duplicate wire values")

        vocabulary = tuple(values)
        existing = self.closed_enums_by_identity.get(identity)
        if existing is not None:
            existing_name, existing_vocabulary = existing
            if existing_name != enum_name or existing_vocabulary != vocabulary:
                raise ValueError(f"closed enum identity {identity!r} was reused with a different schema")
            return existing_name

        owner = self.closed_enum_identity_by_name.get(enum_name)
        if owner is not None and owner != identity:
            raise ValueError(
                f"closed enum type name collision for '{enum_name}': {owner!r} vs {identity!r}"
            )

        constants = [
            {
                'identifier': self._closed_case_identifier(value),
                'wire_literal': self._kotlin_string_literal(value),
            }
            for value in values
        ]
        template = self.code_generator.template_manager.env.get_template('closedEnumClass.jinja')
        enum_code = template.render(
            enum_name=enum_name,
            constants=constants,
        )
        self.code_generator.enum_classes += enum_code + '\n\n'
        self.closed_enums_by_identity[identity] = (enum_name, vocabulary)
        self.closed_enum_identity_by_name[enum_name] = identity
        return enum_name

    def _sanitize_enum_constant(self, value: str) -> str:
        """Convert a string value to a valid Kotlin enum constant name."""
        print(f"Sanitizing enum value: {value}")
        # Comprehensive set of Kotlin keywords
        kotlin_keywords = {
            'as', 'break', 'class', 'continue', 'do', 'else', 'false', 'for',
            'fun', 'if', 'in', 'interface', 'is', 'null', 'object', 'package',
            'return', 'super', 'this', 'throw', 'true', 'try', 'typealias',
            'typeof', 'val', 'var', 'when', 'while', 'data', 'sealed', 'open',
            'internal', 'private', 'protected', 'public', 'override', 'lateinit',
            'by', 'where', 'init', 'companion', 'const', 'constructor', 'delegate',
            'dynamic', 'field', 'file', 'finally', 'get', 'import', 'inner',
            'operator', 'out', 'receiver', 'reified', 'set', 'setparam', 'suspend',
            'tailrec', 'vararg', 'yield'
        }

        # Replace special characters with underscores
        sanitized = value.replace('-', '_').replace('.', '_').replace(':', '_').replace('#', '_').replace('!', '_')

        # Convert to uppercase
        sanitized = sanitized.upper()
        print(f"Sanitized result: {sanitized}", flush=True)

        # If it starts with a digit, prefix with underscore
        if sanitized and sanitized[0].isdigit():
            sanitized = '_' + sanitized

        # If empty or conflicts with Kotlin keywords (case-insensitive check)
        if not sanitized or sanitized.lower() in kotlin_keywords:
            sanitized = 'VALUE_' + sanitized

        return sanitized

    def _get_lexicon_ref(self, ref: str) -> str:
        """Get the lexicon reference string for serialization."""
        # If it's a local reference, build full path
        if not '.' in ref or ref.startswith('#'):
            return f"{self.code_generator.lexicon_id}#{ref.lstrip('#')}"
        return ref
