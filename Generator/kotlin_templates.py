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
        self.lex_definitions_template = self.env.get_template('lexiconDefinitions.jinja')
        self.client_main_template = self.env.get_template('KotlinClientMain.jinja')
