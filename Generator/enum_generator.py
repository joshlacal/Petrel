from utils import convert_to_camel_case, convert_ref, lowercase_first_letter

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

        is_recursive = unique_union_name in self.swift_code_generator.recursive_unions or self.is_enum_recursive(unique_union_name, processed_variants)

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
        refs_info = [{'ref': (self.swift_code_generator.lexicon_id + r if r.startswith('#') else r),
                    'swift_ref': convert_ref(r),
                    'camel_case_label': lowercase_first_letter(convert_ref(r))}
                    for r in refs]
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
