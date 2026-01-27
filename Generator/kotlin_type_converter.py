"""
Kotlin type converter - maps Lexicon types to Kotlin types.
"""
from typing import Dict, List, Any, Optional
from base_code_generator import BaseTypeConverter


def convert_kotlin_ref(ref: str) -> str:
    """Convert a lexicon reference to a Kotlin type name."""
    if ref.startswith('#'):
        # Local reference like #main or #post
        return convert_to_pascal_case(ref[1:])
    else:
        # External reference like com.atproto.repo.strongRef
        parts = ref.split('#')
        base = parts[0]
        fragment = parts[1] if len(parts) > 1 else None

        # Convert dots to nested class notation
        type_name = convert_to_pascal_case(base)

        if fragment:
            type_name += convert_to_pascal_case(fragment)

        return type_name


def convert_to_pascal_case(s: str) -> str:
    """Convert dot-separated or hyphen-separated string to PascalCase."""
    # Handle both dots and hyphens
    s = s.replace('-', '.')
    parts = s.split('.')
    return ''.join(word[0].upper() + word[1:] for word in parts if word)


class KotlinTypeConverter(BaseTypeConverter):
    """Converts lexicon types to Kotlin types."""

    def determine_type(self, name: str, prop_schema: Dict[str, Any],
                       required_fields: List[str], current_struct_name: str) -> str:
        """Determine the Kotlin type for a property."""
        prop_type = prop_schema.get('type', '')
        format_type = prop_schema.get('format', '')
        is_optional = name not in required_fields

        kotlin_type = self._get_base_type(prop_schema, name, current_struct_name)

        # Add nullability for optional fields
        if is_optional and not kotlin_type.endswith('?'):
            kotlin_type += '?'

        return kotlin_type

    def _get_base_type(self, prop_schema: Dict[str, Any], name: str, current_struct_name: str) -> str:
        """Get the base Kotlin type without nullability."""
        prop_type = prop_schema.get('type', '')
        format_type = prop_schema.get('format', '')

        if prop_type == 'string':
            return self._convert_string_type(format_type)
        elif prop_type == 'integer':
            return 'Int'
        elif prop_type == 'number':
            return 'Double'
        elif prop_type == 'boolean':
            return 'Boolean'
        elif prop_type == 'array':
            item_type = self._get_array_item_type(prop_schema, name, current_struct_name)
            return f'List<{item_type}>'
        elif prop_type == 'ref':
            return self.convert_ref(prop_schema['ref'])
        elif prop_type == 'union':
            # Generate union enum type
            union_name = f"{current_struct_name}{convert_to_pascal_case(name)}Union"
            # Register this union with the enum generator
            if hasattr(self.code_generator, 'enum_generator'):
                refs = [self.convert_ref(r) for r in prop_schema.get('refs', [])]
                self.code_generator.enum_generator.generate_sealed_interface_for_union(
                    current_struct_name, name, refs
                )
            return union_name
        elif prop_type == 'blob':
            return 'Blob'
        elif prop_type == 'bytes':
            return 'ByteArray'
        elif prop_type == 'unknown':
            # Special case for DID documents
            if 'didDoc' in name.lower():
                return 'DIDDocument'
            return 'JsonElement'
        elif prop_type == 'object':
            # Generic object - use Map
            return 'Map<String, JsonElement>'
        else:
            # Fallback
            return 'JsonElement'

    def _convert_string_type(self, format_type: str) -> str:
        """Convert string types based on format."""
        format_map = {
            'datetime': 'ATProtocolDate',
            'uri': 'URI',
            'at-uri': 'ATProtocolURI',
            'at-identifier': 'ATIdentifier',
            'did': 'DID',
            'handle': 'Handle',
            'nsid': 'NSID',
            'cid': 'CID',
            'language': 'Language',
        }
        return format_map.get(format_type, 'String')

    def _get_array_item_type(self, prop_schema: Dict[str, Any], name: str, current_struct_name: str) -> str:
        """Determine the type of array items."""
        items_schema = prop_schema.get('items', {})
        items_type = items_schema.get('type', '')

        if items_type == 'ref':
            return self.convert_ref(items_schema['ref'])
        elif items_type == 'union':
            # Generate union for array items
            union_name = f"{current_struct_name}{convert_to_pascal_case(name)}Union"
            if hasattr(self.code_generator, 'enum_generator'):
                refs = [self.convert_ref(r) for r in items_schema.get('refs', [])]
                self.code_generator.enum_generator.generate_sealed_interface_for_union_array(
                    current_struct_name, name, refs
                )
            return union_name
        elif items_type == 'string':
            return self._convert_string_type(items_schema.get('format', ''))
        elif items_type == 'integer':
            return 'Int'
        elif items_type == 'number':
            return 'Double'
        elif items_type == 'boolean':
            return 'Boolean'
        elif items_type == 'unknown':
            return 'JsonElement'
        else:
            return 'JsonElement'

    def convert_primitive(self, type_name: str, format_name: Optional[str] = None) -> str:
        """Convert primitive types."""
        if type_name == 'string':
            return self._convert_string_type(format_name or '')
        elif type_name == 'integer':
            return 'Int'
        elif type_name == 'number':
            return 'Double'
        elif type_name == 'boolean':
            return 'Boolean'
        else:
            return 'JsonElement'

    def convert_ref(self, ref: str) -> str:
        """Convert a lexicon reference to a Kotlin type."""
        if ref.startswith('#'):
            # Local reference
            if ref == '#main':
                return self.code_generator.class_name
            
            # Use prefixed name
            type_name = self.code_generator.class_name + convert_to_pascal_case(ref[1:])
            # No object prefix as definitions are top-level
            return type_name
            
        return convert_kotlin_ref(ref)
