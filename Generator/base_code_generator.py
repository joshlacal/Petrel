"""
Base abstract class for code generators.
Provides common functionality for Swift, Kotlin, and future language generators.
"""
from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional


class BaseCodeGenerator(ABC):
    """Abstract base class for language-specific code generators."""

    def __init__(self, lexicon: Dict[str, Any], cycle_detector=None):
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
