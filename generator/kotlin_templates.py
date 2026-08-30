"""
Kotlin template manager - loads and manages Jinja2 templates for Kotlin code generation.
"""
from jinja2 import Environment, FileSystemLoader, select_autoescape
import os


def to_camel_case(s: str) -> str:
    """Convert PascalCase or snake_case to camelCase."""
    if not s:
        return s
    # If already camelCase or has lowercase first letter, return as-is
    if s[0].islower():
        return s
    # Convert first letter to lowercase
    return s[0].lower() + s[1:]


def to_snake_case(s: str) -> str:
    """Convert PascalCase or camelCase to snake_case."""
    result = []
    for i, char in enumerate(s):
        if char.isupper() and i > 0:
            result.append('_')
        result.append(char.lower())
    return ''.join(result)


def escape_kotlin_comment(s: str) -> str:
    """Escape arbitrary text for use in Kotlin Javadoc / KDoc /** */ comments."""
    if not s:
        return ""
    s = s.replace("*/", "* /").replace("/*", "/ *")
    s = s.replace("$", "\\$")
    lines = s.splitlines()
    return "\n * ".join(line.strip() for line in lines if line.strip())


def escape_kotlin_line_comment(s: str) -> str:
    """Escape arbitrary text for use in Kotlin single-line // comments."""
    if not s:
        return ""
    s = s.replace("*/", "* /").replace("/*", "/ *")
    s = s.replace("$", "\\$")
    lines = s.splitlines()
    return "\n// ".join(line.strip() for line in lines if line.strip())


def escape_kotlin_string_literal(s: str) -> str:
    """Escape arbitrary text for use in Kotlin double-quoted string literals."""
    if not s:
        return ""
    escapes = {
        '\\': '\\\\',
        '"': '\\"',
        '$': '\\$',
        '\n': '\\n',
        '\r': '\\r',
        '\t': '\\t',
        '\b': '\\b',
        '\0': '\\u0000',
    }
    encoded = []
    for char in s:
        if char in escapes:
            encoded.append(escapes[char])
        elif ord(char) < 0x20 or ord(char) == 0x7f or char in ('\u2028', '\u2029'):
            encoded.append(f"\\u{ord(char):04x}")
        else:
            encoded.append(char)
    return "".join(encoded)


def sanitize_kotlin_keyword(s: str) -> str:
    """Escape Kotlin keywords by wrapping in backticks."""
    keywords = {
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

    if s.lower() in keywords:
        return f'`{s}`'
    return s


class KotlinTemplateManager:
    """Manages Jinja2 templates for Kotlin code generation."""

    def __init__(self):
        template_dir = os.path.join(os.path.dirname(__file__), 'templates', 'kotlin')

        self.env = Environment(
            loader=FileSystemLoader(template_dir),
            autoescape=select_autoescape(['html', 'xml']),
            trim_blocks=True,
            lstrip_blocks=True
        )

        # Register custom filters
        self.env.filters['camelCase'] = to_camel_case
        self.env.filters['snakeCase'] = to_snake_case
        self.env.filters['sanitizeKeyword'] = sanitize_kotlin_keyword
        self.env.filters['escapeComment'] = escape_kotlin_comment
        self.env.filters['escapeLineComment'] = escape_kotlin_line_comment
        self.env.filters['escapeStringLiteral'] = escape_kotlin_string_literal
        # Load all templates
        self.main_template = self.env.get_template('mainTemplate.jinja')
        self.properties_template = self.env.get_template('properties.jinja')
        self.query_template = self.env.get_template('query.jinja')
        self.procedure_template = self.env.get_template('procedure.jinja')
        self.subscription_template = self.env.get_template('subscription.jinja')
        self.input_template = self.env.get_template('input.jinja')
        self.output_template = self.env.get_template('output.jinja')
        self.parameters_template = self.env.get_template('parameters.jinja')
        self.sealed_interface_template = self.env.get_template('sealedInterface.jinja')
        self.enum_class_template = self.env.get_template('enumClass.jinja')
        self.errors_enum_template = self.env.get_template('errorsEnum.jinja')
        self.record_template = self.env.get_template('record.jinja')
        self.message_template = self.env.get_template('message.jinja')
        self.lex_definitions_template = self.env.get_template('lexiconDefinitions.jinja')
        self.strict_ref_serializer_template = self.env.get_template('strictRefSerializer.jinja')
        self.client_main_template = self.env.get_template('KotlinClientMain.jinja')
