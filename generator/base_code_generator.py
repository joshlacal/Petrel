"""
Base abstract class for code generators.
Provides common functionality for Swift, Kotlin, and future language generators.
"""
import re
from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional

NSID_PATTERN = re.compile(
    r"^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))+\.[a-zA-Z][a-zA-Z0-9]{0,62}$"
)
DEF_NAME_PATTERN = re.compile(r"^[a-zA-Z][a-zA-Z0-9_-]{0,63}$")
PROPERTY_NAME_PATTERN = re.compile(r"^[a-zA-Z0-9_$]+$")
ERROR_NAME_PATTERN = re.compile(r"^[a-zA-Z0-9_]+$")
REF_PATTERN = re.compile(
    r"^#([a-zA-Z][a-zA-Z0-9_-]{0,63})$|^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))+\.[a-zA-Z][a-zA-Z0-9]{0,62}(#[a-zA-Z][a-zA-Z0-9_-]{0,63})?$"
)


def validate_lexicon_schema(lexicon: Dict[str, Any]) -> None:
    """Validate that lexicon ID, definition names, and properties adhere to grammar."""
    lexicon_id = lexicon.get("id")
    if not isinstance(lexicon_id, str) or not NSID_PATTERN.match(lexicon_id):
        raise ValueError(f"Invalid lexicon NSID: {lexicon_id!r}")

    defs = lexicon.get("defs", {})
    if not isinstance(defs, dict):
        raise ValueError(f"Lexicon defs must be a dictionary in {lexicon_id!r}")

    for def_name, def_schema in defs.items():
        if not isinstance(def_name, str) or not DEF_NAME_PATTERN.match(def_name):
            raise ValueError(f"Invalid definition name {def_name!r} in {lexicon_id!r}")
        _validate_def_schema_properties_and_errors(lexicon_id, def_schema)


def _validate_def_schema_properties_and_errors(lexicon_id: str, node: Any) -> None:
    if not isinstance(node, dict):
        return

    if "ref" in node:
        ref_val = node.get("ref")
        if not isinstance(ref_val, str) or not REF_PATTERN.match(ref_val):
            raise ValueError(f"Invalid ref {ref_val!r} in {lexicon_id!r}")

    if "refs" in node:
        refs_val = node.get("refs")
        if not isinstance(refs_val, list):
            raise ValueError(f"Invalid refs list {refs_val!r} in {lexicon_id!r}")
        for r in refs_val:
            if not isinstance(r, str) or not REF_PATTERN.match(r):
                raise ValueError(f"Invalid ref {r!r} in {lexicon_id!r}")
    properties = node.get("properties")
    if isinstance(properties, dict):
        for prop_name, prop_schema in properties.items():
            if not isinstance(prop_name, str) or not PROPERTY_NAME_PATTERN.match(prop_name):
                raise ValueError(f"Invalid property name {prop_name!r} in {lexicon_id!r}")
            _validate_def_schema_properties_and_errors(lexicon_id, prop_schema)

    errors = node.get("errors")
    if isinstance(errors, list):
        for error_item in errors:
            if isinstance(error_item, dict):
                error_name = error_item.get("name")
                if not isinstance(error_name, str) or not ERROR_NAME_PATTERN.match(error_name):
                    raise ValueError(f"Invalid error name {error_name!r} in {lexicon_id!r}")

    for key in ("input", "output", "parameters", "message", "record", "items"):
        if key in node:
            _validate_def_schema_properties_and_errors(lexicon_id, node[key])

    schema = node.get("schema")
    if isinstance(schema, dict):
        _validate_def_schema_properties_and_errors(lexicon_id, schema)
class BaseCodeGenerator(ABC):
    """Abstract base class for language-specific code generators."""

    def __init__(self, lexicon: Dict[str, Any], cycle_detector=None):
        validate_lexicon_schema(lexicon)
        self.lexicon = lexicon
        self.defs = lexicon.get('defs', {})
        self.lexicon_id = lexicon.get('id', '')
        self.lexicon_version = lexicon.get('lexicon', 1)

        # Extract description
        top_level_description = lexicon.get('description', '')
        nested_description = lexicon.get('defs', {}).get('main', {}).get('description', '')
        self.description = f"{top_level_description} {nested_description}".strip()
        self.cycle_detector = cycle_detector
        self.main_def = self.defs.get('main', {})

    @abstractmethod
    def convert(self) -> str:
        """
        Generate code for the lexicon.
        Returns the complete generated code as a string.
        """
        pass

    @abstractmethod
    def get_file_extension(self) -> str:
        """Return the file extension for this language (e.g., '.swift', '.kt')."""
        pass

    def is_blob_upload(self) -> bool:
        """Check if this is a blob upload procedure."""
        main_def = self.defs.get('main', {})
        encoding = main_def.get('input', {}).get('encoding', '')
        return main_def.get('type') == 'procedure' and encoding == '*/*'

    def is_binary_data(self, encoding: str) -> bool:
        """Check if encoding represents binary data."""
        return encoding != '' and encoding != 'application/json'


class BaseTypeConverter(ABC):
    """Abstract base class for type conversion between lexicon types and target language types."""

    def __init__(self, code_generator):
        self.code_generator = code_generator

    @abstractmethod
    def determine_type(self, name: str, prop_schema: Dict[str, Any],
                       required_fields: List[str], current_struct_name: str) -> str:
        """
        Determine the target language type for a lexicon property.

        Args:
            name: Property name
            prop_schema: Property schema from lexicon
            required_fields: List of required field names
            current_struct_name: Name of the containing struct/class

        Returns:
            String representation of the type in target language
        """
        pass

    @abstractmethod
    def convert_primitive(self, type_name: str, format_name: Optional[str] = None) -> str:
        """Convert primitive types (string, integer, boolean, etc.)."""
        pass

    @abstractmethod
    def convert_ref(self, ref: str) -> str:
        """Convert a lexicon reference to a target language type."""
        pass
