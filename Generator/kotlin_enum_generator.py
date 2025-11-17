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

    def generate_sealed_interface_for_union(self, current_struct_name: str, prop_name: str, refs: List[str]):
        """Generate a sealed interface for a union type property."""
        union_name = f"{current_struct_name}{convert_to_pascal_case(prop_name)}Union"

        if union_name in self.generated_sealed_interfaces:
            return

        self.generated_sealed_interfaces.add(union_name)

        # Build variant cases
        variants = []
        for ref in refs:
            # Extract the last part of the ref as the variant name
            variant_name = ref.split('.')[-1]
            variants.append({
                'name': variant_name,
                'type': ref,
                'lexicon_ref': self._get_lexicon_ref(ref)
            })

        # Render the sealed interface
        template = self.code_generator.template_manager.sealed_interface_template
        sealed_code = template.render(
            union_name=union_name,
            variants=variants,
            lexicon_id=self.code_generator.lexicon_id
        )

        self.code_generator.sealed_interfaces += sealed_code + '\n\n'

    def generate_sealed_interface_for_union_array(self, current_struct_name: str, prop_name: str, refs: List[str]):
        """Generate a sealed interface for an array of unions."""
        # Same as regular union for Kotlin
        self.generate_sealed_interface_for_union(current_struct_name, prop_name, refs)

    def generate_enum_class_from_known_values(self, enum_name: str, known_values: List[str], descriptions: dict = None):
        """Generate an enum class from known values."""
        if enum_name in self.generated_enum_classes:
            return

        self.generated_enum_classes.add(enum_name)

        # Sanitize enum constant names
        constants = []
        for value in known_values:
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

    def _sanitize_enum_constant(self, value: str) -> str:
        """Convert a string value to a valid Kotlin enum constant name."""
        # Replace special characters with underscores
        sanitized = value.replace('-', '_').replace('.', '_').replace(':', '_')

        # Convert to uppercase
        sanitized = sanitized.upper()

        # If it starts with a digit, prefix with underscore
        if sanitized and sanitized[0].isdigit():
            sanitized = '_' + sanitized

        # If empty or conflicts with Kotlin keywords, use a safe name
        if not sanitized or sanitized in ['NULL', 'TRUE', 'FALSE']:
            sanitized = 'VALUE_' + sanitized

        return sanitized

    def _get_lexicon_ref(self, ref: str) -> str:
        """Get the lexicon reference string for serialization."""
        # If it's a local reference, build full path
        if not '.' in ref or ref.startswith('#'):
            return f"{self.code_generator.lexicon_id}#{ref.lstrip('#')}"
        return ref
