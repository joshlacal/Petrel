from utils import convert_to_camel_case, lowercase_first_letter

class EnumGenerator:
    def __init__(self, swift_code_generator):
        self.swift_code_generator = swift_code_generator

    def generate_enum_for_union(self, context_struct_name, union_name, variants):
        unique_union_name = f"{context_struct_name}{convert_to_camel_case(union_name)}Union"

        if unique_union_name in self.swift_code_generator.generated_unions:
            return

        self.swift_code_generator.generated_unions.add(unique_union_name)

        processed_variants = [self.swift_code_generator.lexicon_id + variant if variant.startswith('#') else variant for variant in variants]

        self.swift_code_generator.enum_definitions[unique_union_name] = processed_variants

        # Check if enum should be indirect using cycle detector
        cycle_detector = self.swift_code_generator.cycle_detector
        if cycle_detector:
            # Build fully qualified name for cycle detector lookup
            # If context_struct_name doesn't contain the base type, prepend it
            swift_base = convert_to_camel_case(self.swift_code_generator.lexicon_id)
            if context_struct_name == swift_base:
                # Main def: union name is just base.UnionName
                qualified_union_name = unique_union_name
            elif not context_struct_name.startswith(swift_base):
                # Nested def: need to add base and dot
                qualified_union_name = f"{swift_base}.{unique_union_name}"
            else:
                # Already has base in the name
                qualified_union_name = unique_union_name

            is_recursive = cycle_detector.should_be_indirect(qualified_union_name)
        else:
            # Fallback to old detection if no cycle detector
            is_recursive = self.is_enum_recursive(unique_union_name, processed_variants)

        enum_template = self.swift_code_generator.template_manager.env.get_template('unionEnum.jinja')

        enum_code = enum_template.render(
            name=unique_union_name, 
            variants=processed_variants, 
            lexicon_id=self.swift_code_generator.lexicon_id,
            is_recursive=is_recursive
        )
        self.swift_code_generator.enums += enum_code + "\n\n"

    def is_enum_recursive(self, enum_name, variants):
        def check_recursive(name, seen):
            if name in seen:
                return True
            seen.add(name)
            for variant in self.swift_code_generator.enum_definitions.get(name, []):
                if variant in self.swift_code_generator.enum_definitions:
                    if check_recursive(variant, seen):
                        return True
            seen.remove(name)
            return False
        
        return check_recursive(enum_name, set())

    def generate_enum_for_union_array(self, context_struct_name, name, refs):
        unique_union_name = convert_to_camel_case(name)
        
        if unique_union_name in self.swift_code_generator.generated_unions:
            return

        self.swift_code_generator.generated_unions.add(unique_union_name)
        refs_info = []
        for ref in refs:
            swift_ref = self.swift_code_generator.type_converter.convert_ref(ref)
            refs_info.append({
                'ref': self.swift_code_generator.lexicon_id + ref if ref.startswith('#') else ref,
                'swift_ref': swift_ref,
                'camel_case_label': lowercase_first_letter(swift_ref),
            })
        union_array_template = self.swift_code_generator.template_manager.env.get_template('unionArray.jinja')
        swift_code = union_array_template.render(array_name=name, union_name=unique_union_name, refs=refs_info, lexicon_id=self.swift_code_generator.lexicon_id)
        self.swift_code_generator.enums += swift_code + "\n\n"

    def generate_enum_from_known_values(self, enum_name, known_values, descriptions):
        if enum_name in self.swift_code_generator.generated_tokens:
            return

        template = self.swift_code_generator.template_manager.env.get_template('knownValuesEnum.jinja')
        values_with_descriptions = [(val, descriptions.get(val, '')) for val in known_values]
        enum_code = template.render(enum_name=enum_name, values=values_with_descriptions)
        self.swift_code_generator.enums += enum_code + "\n\n"
        self.swift_code_generator.generated_tokens.add(enum_name)

    @staticmethod
    def _case_identifier(value):
        encoded = ''.join(
            char if char.isascii() and char.isalnum() else f'_u{ord(char):x}_'
            for char in value
        )
        return f"value_{encoded}"

    @staticmethod
    def _swift_string_literal(value):
        escapes = {
            '\\': '\\\\',
            '"': '\\"',
            '\n': '\\n',
            '\r': '\\r',
            '\t': '\\t',
            '\0': '\\0',
        }
        encoded = []
        for char in value:
            if char in escapes:
                encoded.append(escapes[char])
            elif ord(char) < 0x20 or ord(char) == 0x7f or char in ('\u2028', '\u2029'):
                encoded.append(f"\\u{{{ord(char):x}}}")
            else:
                encoded.append(char)
        return f'"{"".join(encoded)}"'

    def generate_closed_string_enum(self, enum_name, values, identity):
        if not isinstance(values, list) or not all(isinstance(value, str) for value in values):
            raise ValueError(f"closed enum '{enum_name}' values must be a list of strings")
        if len(values) != len(set(values)):
            raise ValueError(f"closed enum '{enum_name}' contains duplicate wire values")

        vocabulary = tuple(values)
        existing = self.swift_code_generator.closed_enums_by_identity.get(identity)
        if existing is not None:
            existing_name, existing_vocabulary = existing
            if existing_name != enum_name or existing_vocabulary != vocabulary:
                raise ValueError(f"closed enum identity {identity!r} was reused with a different schema")
            return existing_name

        owner = self.swift_code_generator.closed_enum_identity_by_name.get(enum_name)
        if owner is not None and owner != identity:
            raise ValueError(
                f"closed enum type name collision for '{enum_name}': {owner!r} vs {identity!r}"
            )

        template = self.swift_code_generator.template_manager.env.get_template('closedStringEnum.jinja')
        cases = [
            {
                'identifier': self._case_identifier(value),
                'wire_literal': self._swift_string_literal(value),
            }
            for value in values
        ]
        enum_code = template.render(enum_name=enum_name, cases=cases)
        self.swift_code_generator.enums += enum_code + "\n\n"
        self.swift_code_generator.closed_enums_by_identity[identity] = (enum_name, vocabulary)
        self.swift_code_generator.closed_enum_identity_by_name[enum_name] = identity
        return enum_name
