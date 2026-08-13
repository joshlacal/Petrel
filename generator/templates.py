import os
import jinja2
from utils import convert_to_camel_case

# Swift reserved keywords that cannot be used as bare identifiers.
# Mirror of sanitize_kotlin_keyword in kotlin_templates.py. Case-sensitive:
# only Any/Self are reserved capitalized; `Protocol`, `Type` etc. are fine.
SWIFT_KEYWORDS = {
    # Declaration keywords
    'associatedtype', 'class', 'deinit', 'enum', 'extension', 'fileprivate',
    'func', 'import', 'init', 'inout', 'internal', 'let', 'open', 'operator',
    'private', 'precedencegroup', 'protocol', 'public', 'rethrows', 'static',
    'struct', 'subscript', 'typealias', 'var',
    # Statement keywords
    'break', 'case', 'catch', 'continue', 'default', 'defer', 'do', 'else',
    'fallthrough', 'for', 'guard', 'if', 'in', 'repeat', 'return', 'switch',
    'where', 'while', 'throw',
    # Expression/type keywords
    'Any', 'as', 'false', 'is', 'nil', 'self', 'Self', 'super', 'true',
    'throws', 'try',
}


def sanitize_swift_keyword(s: str) -> str:
    """Escape Swift reserved keywords by wrapping in backticks.

    Applied only at identifier positions in templates (declarations, member
    access, CodingKeys cases) — never inside string literals, where the raw
    wire name must be preserved. A backticked enum case still gets the
    unescaped implicit raw value, so CodingKeys stay wire-correct.
    """
    if s in SWIFT_KEYWORDS:
        return f'`{s}`'
    return s


class TemplateManager:
    def __init__(self):
        script_dir = os.path.dirname(os.path.realpath(__file__))
        templates_dir = os.path.join(script_dir, 'templates')
        self.env = jinja2.Environment(loader=jinja2.FileSystemLoader(templates_dir))

        self.env.filters['lowerCamelCase'] = self.lowerCamelCase
        self.env.filters['convertRefToSwift'] = self.convert_ref_to_swift
        self.env.filters['enum_case'] = self.enum_case_filter
        self.env.filters['sanitizeKeyword'] = sanitize_swift_keyword

        self.main_template = self.env.get_template('mainTemplate.jinja')
        self.properties_template = self.env.get_template('properties.jinja')
        self.query_parameters_template = self.env.get_template('parameters.jinja')
        self.input_struct_template = self.env.get_template('input.jinja')
        self.output_struct_template = self.env.get_template('output.jinja')
        self.errors_enum_template = self.env.get_template('errorsEnum.jinja')
        self.lex_definitions_template = self.env.get_template('lexiconDefinitions.jinja')
        self.record_template = self.env.get_template('record.jinja')
        self.query_template = self.env.get_template('query.jinja')
        self.procedure_template = self.env.get_template('procedure.jinja')
        self.subscription_template = self.env.get_template('subscription.jinja')
        self.message_union_template = self.env.get_template('messageUnion.jinja')

    @staticmethod
    def lowerCamelCase(s):
        parts = s.split('.')
        camel_cased_parts = []
        for part in parts:
            sub_parts = part.split('_')
            camel_cased = sub_parts[0] + ''.join(sub.title() for sub in sub_parts[1:])
            camel_cased_parts.append(camel_cased)
        final_string = ''.join(camel_cased_parts)
        return final_string[0].lower() + final_string[1:] if final_string else final_string

    @staticmethod
    def convert_ref_to_swift(ref: str) -> str:
        if '#' in ref:
            parts = ref.split('#')
            if parts[0] == '':
                return convert_to_camel_case(parts[1])
            else:
                pre_hash_parts = parts[0].split('.')
                camel_case_pre_hash = ''.join([convert_to_camel_case(part) for part in pre_hash_parts])
                return camel_case_pre_hash + '.' + convert_to_camel_case(parts[1])
        else:
            return convert_to_camel_case(ref)

    @staticmethod
    def enum_case_filter(value: str) -> str:
        import re
        value = re.sub(r'[!]', 'exclamation', value)
        value = re.sub(r'[\-]', 'Dash', value)
        value = re.sub(r'[^a-zA-Z0-9_]', '', value)
        if value[0].isdigit():
            value = 'Number' + value
        return TemplateManager.to_lower_camel_case(value)

    @staticmethod
    def to_lower_camel_case(value: str) -> str:
        parts = value.split('_')
        return parts[0].lower() + ''.join(word.capitalize() for word in parts[1:])
