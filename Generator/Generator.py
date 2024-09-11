import json
import jinja2
from typing import Dict, List, Any, Optional
import re
import os, sys
import concurrent.futures

class SwiftCodeGenerator:
    def __init__(self, lexicon: Dict[str, Any]):
        self.lexicon = lexicon
        self.defs = lexicon.get('defs', {})
        self.lexicon_id = lexicon.get('id', '')
        self.lexicon_version = lexicon.get('lexicon', 1)
        top_level_description = lexicon.get('description', '')
        nested_description = lexicon.get('defs', {}).get('main', {}).get('description', '')
        self.description = f"{top_level_description} {nested_description}".strip()
        self.struct_name = self.convert_to_camel_case(self.lexicon_id)
        self.conformance = ""
        self.enums = ""
        self.generated_unions = set()
        self.enum_definitions = {}  # New dictionary to track enum definitions
        self.recursive_unions = {"ThreadViewPostParentUnion", "ThreadViewPostRepliesUnion", "OutputThreadUnion"}
        self.is_blob_upload = self.check_if_blob_upload(lexicon)

        self.token_descriptions = {}
        self.generated_tokens = set()
        script_dir = os.path.dirname(os.path.realpath(__file__))
        templates_dir = os.path.join(script_dir, 'templates')
        self.env = jinja2.Environment(loader=jinja2.FileSystemLoader(templates_dir))

        self.env.filters['lowerCamelCase'] = self.lowerCamelCase
        self.env.filters['convertRefToSwift'] = self.convert_ref_to_swift
        self.env.filters['enum_case'] = self.enum_case_filter

        # Initialize Jinja2 templates
        self.main_template = self.init_main_template()
        self.properties_template = self.init_properties_template()
        self.query_parameters_template = self.init_query_parameters_template()
        self.input_struct_template = self.init_input_struct_template()
        self.output_struct_template = self.init_output_struct_template()
        self.errors_enum_template = self.init_errors_enum_template()
        self.lex_definitions_template = self.init_lex_definitions_template()
        self.record_template = self.init_record_template()
        self.query_template = self.init_query_template()
        self.procedure_template = self.init_procedure_template()

        # Handle different types of definitions
        self.main_def = self.handle_main_def()  

    def check_if_blob_upload(self, lexicon: Dict[str, Any]) -> bool:
        main_def = lexicon.get('defs', {}).get('main', {})
        return main_def.get('type') == 'procedure' and \
               main_def.get('input', {}).get('encoding') == '*/*'


    def init_main_template(self):
        return self.env.get_template('mainTemplate.jinja')
    
    def init_query_template(self):
        return self.env.get_template('query.jinja')
    
    def init_procedure_template(self):
        return self.env.get_template('procedure.jinja')

    def lowerCamelCase(self, s):
        parts = s.split('.')
        camel_cased_parts = []
        for part in parts:
            sub_parts = part.split('_')
            # Capitalize all parts except the first one and join them to form camelCase
            camel_cased = sub_parts[0] + ''.join(sub.title() for sub in sub_parts[1:])
            camel_cased_parts.append(camel_cased)
        final_string = ''.join(camel_cased_parts)
        # Make the first letter of the final string lowercase
        return final_string[0].lower() + final_string[1:] if final_string else final_string

    def convert_ref_to_swift(self, ref: str) -> str:
        """Converts a reference to Swift case."""
        if '#' in ref:
            parts = ref.split('#')
            if parts[0] == '':
                # Handle the case like "#viewerState"
                return self.convert_to_camel_case(parts[1])
            else:
                # Handle the case like "com.atproto.label.defs#label"
                pre_hash_parts = parts[0].split('.')
                camel_case_pre_hash = ''.join([self.convert_to_camel_case(part) for part in pre_hash_parts])
                return camel_case_pre_hash + '.' + self.convert_to_camel_case(parts[1])
        else:
            # Handle the case without '#'
            return self.convert_to_camel_case(ref)

    def to_lower_camel_case(self, value: str) -> str:
        parts = value.split('_')
        # Capitalize each part except the first one and join them to form camelCase
        camel_cased = parts[0].lower() + ''.join(word.capitalize() for word in parts[1:])
        return camel_cased
        
    def enum_case_filter(self, value: str) -> str:
        # Replace invalid characters with underscores or appropriate alternatives
        value = re.sub(r'[!]', 'exclamation', value)
        value = re.sub(r'[\-]', 'Dash', value)

        # Replace any other non-alphanumeric characters (excluding underscores)
        value = re.sub(r'[^a-zA-Z0-9_]', '', value)

        # Ensure it doesn't start with a number
        if value[0].isdigit():
            value = 'Number' + value

        # Convert to lowerCamelCase
        value = self.to_lower_camel_case(value)

        return value


    def init_properties_template(self):
        return self.env.get_template('properties.jinja')

    def init_query_parameters_template(self):
        return self.env.get_template('parameters.jinja')

    def init_input_struct_template(self):
        return self.env.get_template('input.jinja')

    def init_output_struct_template(self):
        return self.env.get_template('output.jinja')

    def init_errors_enum_template(self):
        return self.env.get_template('errorsEnum.jinja')

    def init_lex_definitions_template(self):
        return self.env.get_template('lexiconDefinitions.jinja')
    
    def init_record_template(self):
        return self.env.get_template('record.jinja')
    
    def init_enum_from_known_values_template(self):
        return self.env.get_template('knownValuesEnum.jinja')


    def generate_enum_for_union(self, context_struct_name, union_name, variants):
        # Create a unique name incorporating the context
        unique_union_name = f"{context_struct_name}{self.convert_to_camel_case(union_name)}Union"
        
        # Check if we've already generated this union
        if unique_union_name in self.generated_unions:
            return

        self.generated_unions.add(unique_union_name)

        # Process variants to prepend lexicon_id if they start with '#'
        processed_variants = [self.lexicon_id + variant if variant.startswith('#') else variant for variant in variants]

        # Track the enum definition
        self.enum_definitions[unique_union_name] = processed_variants

        # Detect if the enum is recursive
        is_recursive = unique_union_name in self.recursive_unions or self.is_enum_recursive(unique_union_name, processed_variants)

        enum_template = self.env.get_template('unionEnum.jinja')

        enum_code = enum_template.render(
            name=unique_union_name, 
            variants=processed_variants, 
            lexicon_id=self.lexicon_id,
            is_recursive=is_recursive  # Pass the recursion info to the template
        )
        self.enums += enum_code + "\n\n"

    def is_enum_recursive(self, enum_name, variants):
        """Detects if an enum is recursive."""
        def check_recursive(name, seen):
            if name in seen:
                return True
            seen.add(name)
            for variant in self.enum_definitions.get(name, []):
                if variant in self.enum_definitions:
                    if check_recursive(variant, seen):
                        return True
            seen.remove(name)
            return False
        
        return check_recursive(enum_name, set())

    @staticmethod
    def lowercase_first_letter(s):
        if not s:
            return s
        return s[0].lower() + s[1:]
    

    def generate_enum_for_union_array(self, context_struct_name, name, refs):
        # Create a unique name incorporating the context
        unique_union_name = self.convert_to_camel_case(name)
        
        # Check if we've already generated this union
        if unique_union_name in self.generated_unions:
            return  # Skip if this union was already generated

        self.generated_unions.add(unique_union_name)
        refs_info = [{'ref': (self.lexicon_id + r if r.startswith('#') else r),
                    'swift_ref': self.convert_ref(r),
                    'camel_case_label': self.lowercase_first_letter(self.convert_ref(r))}
                    for r in refs]
        union_array_template = self.env.get_template('unionArray.jinja')
        swift_code = union_array_template.render(array_name=name, union_name=unique_union_name, refs=refs_info, lexicon_id=self.lexicon_id)
        self.enums += swift_code + "\n\n"


    def generate_enum_from_known_values(self, enum_name, known_values, descriptions):
        if enum_name in self.generated_tokens:
            return  # Skip if already generated

        template = self.init_enum_from_known_values_template()
        values_with_descriptions = [(val, descriptions.get(val, '')) for val in known_values]
        enum_code = template.render(enum_name=enum_name, values=values_with_descriptions)
        self.enums += enum_code + "\n\n"
        self.generated_tokens.add(enum_name)  # Add to tracked enums


    def generate_procedure_function(self, lexicon_id, main_def):
        template_namespace_parts = lexicon_id.split('.')[:-1]  # Everything except the last part
        template_namespace_name = '.'.join(self.convert_to_camel_case(part) for part in template_namespace_parts)
        procedure_name = self.convert_to_camel_case(lexicon_id.split('.')[-1])

        # Check if this is an initial setup procedure, like session creation or server description
        during_initial_setup = (
            'createSession' in lexicon_id or
            'createAccount' in lexicon_id
        )

        # Check if this is a blob upload procedure
        is_blob_upload = 'input' in main_def and main_def['input'].get('encoding') == '*/*'

        input_parameters = ''
        input_values = ''
        input_struct_name = None
        if 'input' in main_def and 'schema' in main_def['input']:
            input_params = main_def['input']['schema'].get('properties', {})
            current_struct_name = self.convert_to_camel_case(lexicon_id)  # Use the lexicon ID to create a struct name
            input_parameters = ', '.join([f"{param}: {self.determine_swift_type(param, details, main_def['input'].get('required', []), current_struct_name)}" for param, details in input_params.items()])
            input_values = ', '.join([f"{param}: {param}" for param in input_params.keys()])
            input_struct_name = self.convert_to_camel_case(lexicon_id) + ".Input"

        # Correct endpoint format
        endpoint = f"/{lexicon_id}"

        return self.procedure_template.render(
            template_namespace_name=template_namespace_name,
            procedure_name=procedure_name,
            input_parameters=input_parameters,
            input_struct_name=input_struct_name,
            input_values=input_values,
            output_type=self.convert_to_camel_case(lexicon_id) + ".Output" if 'output' in main_def else None,
            endpoint=endpoint,
            description=self.description,
            during_initial_setup=during_initial_setup,
            is_blob_upload=is_blob_upload
        )

    def generate_query_function(self, lexicon_id, main_def):
        template_namespace_parts = lexicon_id.split('.')[:-1]  # Everything except the last part
        template_namespace_name = '.'.join(self.convert_to_camel_case(part) for part in template_namespace_parts)

        query_name = self.convert_to_camel_case(lexicon_id.split('.')[-1])

        # Check if this is an initial setup query, like describing the server
        during_initial_setup = 'describeServer' in lexicon_id

        # Check if input and output are present
        has_input = 'parameters' in main_def
        input_struct_name = self.convert_to_camel_case(lexicon_id) + ".Parameters" if has_input else None
        output_type = self.convert_to_camel_case(lexicon_id) + ".Output" if 'output' in main_def else None

        # Prepare input parameters and values only if input is present
        input_parameters = ''
        input_values = ''
        if has_input:
            input_params = main_def.get('parameters', {}).get('properties', {})
            input_parameters = ', '.join([f"{param}: {self.determine_swift_type(param, details, main_def.get('parameters', {}).get('required', []),param)}" for param, details in input_params.items()])
            input_values = ', '.join([f"{param}: {param}" for param in input_params.keys()])

        # Correct endpoint format
        endpoint = f"/{lexicon_id}"

        # Render the query template
        return self.query_template.render(
            template_namespace_name=template_namespace_name,
            query_name=query_name,
            input_parameters=input_parameters,
            input_struct_name=input_struct_name,
            input_values=input_values,
            output_type=output_type,
            endpoint=endpoint,
            description=self.description,
            during_initial_setup=during_initial_setup
        )


    @staticmethod
    def convert_to_camel_case(name: str) -> str:
        """Converts a string to CamelCase."""
        return ''.join(part[0].upper() + part[1:] for part in name.split('.'))
    
    @staticmethod
    def convert_to_lower_camel_case(name: str) -> str:
        """Converts a string to lowerCamelCase."""
        parts = name.split('.')
        return parts[0].lower() + ''.join(part.capitalize() for part in parts[1:])

    
    
    @staticmethod
    def post_process_swift_code(code: str) -> str:
        # Add extra newline before every "struct" and "enum"
        code = code.replace('public struct ', '\npublic struct ')
        code = code.replace('public enum ', '\npublic enum ')
#        code = code.replace('extension ', '\nextension ')
        
        # Remove potential extra newlines at the beginning
        return code.lstrip()


    def convert_ref(self, ref: str) -> str:
        """Converts a reference to Swift format."""
        if '#' in ref:
            parts = ref.split('#')
            if parts[0] == '':
                # Handle the case like "#viewerState"
                return self.convert_to_camel_case(parts[1])
            else:
                # Handle the case like "com.atproto.label.defs#label"
                pre_hash_parts = parts[0].split('.')
                camel_case_pre_hash = ''.join([self.convert_to_camel_case(part) for part in pre_hash_parts])
                return camel_case_pre_hash + '.' + self.convert_to_camel_case(parts[1])
        else:
            # Handle the case without '#'
            return self.convert_to_camel_case(ref)


    def generate_properties(self, properties, required_fields, current_struct_name):
        swift_properties = []
        for name, prop in properties.items():
            swift_type = self.determine_swift_type(name, prop, required_fields, current_struct_name)
            description = prop.get('description', '')  # Capture the description
            is_optional = name not in required_fields
            swift_properties.append({
                'name': name, 
                'type': swift_type, 
                'optional': is_optional,
                'description': description  # Include the description
            })
        return swift_properties

    def determine_swift_type(self, name: str, prop: Dict[str, Any], required_fields: List[str], current_struct_name: str, isOptional: Optional[bool] = None) -> str:
        swift_type = ""
        prop_type = prop.get('type')
        string_format = prop.get('format')
        is_optional = "?" if isOptional or name not in required_fields else ""

        if prop_type == 'string':
            if string_format == 'datetime':
                swift_type = "ATProtocolDate"
            elif string_format == 'uri':
                swift_type = "URI" 
            elif string_format == 'at-uri':
                swift_type = "ATProtocolURI" 
            elif string_format == 'language':
                swift_type = "LanguageCodeContainer"
            else:
                swift_type = "String" 
        elif prop_type == 'ref':
            swift_type = self.convert_ref(prop['ref']) 
        elif prop_type == 'integer':
            swift_type = "Int" 
        elif prop_type == 'number':
            swift_type = "Double" 
        elif prop_type == 'boolean':
            swift_type = "Bool" 
        elif prop_type == 'object':
            swift_type = "[String: ATProtocolValueContainer]" 
        elif prop_type == 'unknown':
            if name == 'didDoc':
                swift_type = "DIDDocument"
            else:
                swift_type = "ATProtocolValueContainer"
        elif prop_type == 'union':
            union_name = f"{self.convert_to_camel_case(current_struct_name)}{self.convert_to_camel_case(name)}Union"
            refs = prop.get('refs', [])
            self.generate_enum_for_union(current_struct_name, name, refs)
            return union_name
        elif prop_type == 'array':
            items = prop['items']
            if items.get('type') == 'union':
                union_name = f"{self.convert_to_camel_case(current_struct_name)}{self.convert_to_camel_case(name)}Union"
                refs = items['refs']
                self.generate_enum_for_union(current_struct_name, name, refs)
                item_type = union_name
            else:
                # Recursive call with current_struct_name
                item_type = self.determine_swift_type(name, items, required_fields, current_struct_name, isOptional=False)
            swift_type = f"[{item_type}]"
        else:
            swift_type = prop_type.capitalize()

        return swift_type
    
    def generate_record_struct(self, record_schema, defs):
        if not record_schema:
            return ""
        
        properties = self.generate_properties(record_schema.get('properties', {}), record_schema.get('required', []), defs)
        return properties

    def generate_query_parameters(self, parameters: Optional[Dict[str, Any]]) -> str:
        if not parameters:
            return ""
        properties = self.generate_properties(parameters['properties'], parameters.get('required', []), "Parameters")
        return self.query_parameters_template.render(properties=properties)

    def generate_input_struct(self, input_obj: Optional[Dict[str, Any]]) -> str:
        if not input_obj or 'schema' not in input_obj:
            return ""
        
        input_schema = input_obj['schema']
        encoding = input_obj.get('encoding', '')
        conformance = ": ATProtocolCodable" if encoding == "application/json" else ""

        properties = ""
        if encoding == "*/*":
            properties = [{"name": "data", "type": "Data", "optional": False}]
        elif input_schema.get('type') == 'ref':
            # Handle reference type
            ref_type = self.convert_ref_to_swift(input_schema['ref'])
            properties = [{"name": "data", "type": ref_type, "optional": False}]
        else:
            properties = self.generate_properties(input_schema.get('properties', {}), input_schema.get('required', []), "Input")

        return self.input_struct_template.render(properties=properties, conformance=conformance)
    
    def generate_output_struct(self, output_obj: Optional[Dict[str, Any]]) -> str:
        if not output_obj:
            return ""

        encoding = output_obj.get('encoding', '')
        output_schema = output_obj.get('schema', {})

        # Context for template rendering
        context = {
            'conformance': ": ATProtocolCodable" if encoding == "application/json" else "",
            'is_type_alias': False,  # Default to false
            'properties': [],
            'type_alias_target': None,
        }

        if output_schema.get('type') == 'ref':
            # If the schema is a reference, set to generate a typealias
            context['is_type_alias'] = True
            context['type_alias_target'] = self.convert_ref_to_swift(output_schema['ref'])
        elif encoding == "*/*":
            # Handle special case where encoding is "*/*"
            context['properties'] = [{"name": "data", "type": "Data", "optional": False}]
        else:
            # Generate properties for the struct
            context['properties'] = self.generate_properties(output_schema.get('properties', {}), output_schema.get('required', []), "Output")

        return self.output_struct_template.render(**context)

    def generate_errors_enum(self, errors: Optional[List[Dict[str, str]]]) -> str:
        if not errors:
            return ""
        return self.errors_enum_template.render(errors=errors)
    
    def is_union_array(self, def_schema):
        return def_schema.get('type') == 'array' and 'refs' in def_schema.get('items', {})

    
    def generate_lex_definitions(self):
        lex_definitions = {}
        token_definitions = []
        for name, def_schema in self.defs.items():
            # Skip struct generation if it's a union array
            current_struct_name = self.convert_to_camel_case(name)
            
            if self.is_union_array(def_schema):
                refs = def_schema['items']['refs']
                self.generate_enum_for_union_array(current_struct_name, name, refs)
                continue
            if name != 'main' and def_schema.get('type', "") == "object":
                conformance = ": ATProtocolCodable, ATProtocolValue"
                properties = self.generate_properties(def_schema.get('properties', {}), def_schema.get('required', []), current_struct_name)
                
                # Generate sub-structs for each key in the definition
                sub_structs = {}
                for key, value in def_schema.items():
                    if key not in ['properties', 'required', 'type', 'description']:
                        sub_conformance = ": ATProtocolCodable, ATProtocolValue"
                        sub_properties = self.generate_properties(value.get('properties', {}), value.get('required', []))
                        sub_structs[self.convert_to_camel_case(key)] = {
                            'properties': sub_properties, 
                            'conformance': sub_conformance
                        }
                
                lex_definitions[self.convert_to_camel_case(name)] = {
                    'properties': properties, 
                    'conformance': conformance,
                    'sub_structs': sub_structs
                }
            elif def_schema.get('type', '') == "array" and def_schema.get('items', {}).get('type', '') == 'union':
                # Handle arrays of unions
                union_array_name = self.convert_to_camel_case(name) + ""
                refs = def_schema['items'].get('refs', [])
                self.generate_enum_for_union_array(current_struct_name, union_array_name, refs)
                properties = [{
                    'name': self.convert_to_lower_camel_case(name),
                    'type': f'[{union_array_name}]',
                    'optional': False
                }]
                lex_definitions[union_array_name] = {
                    'properties': properties,
                    'conformance': ': ATProtocolCodable, ATProtocolValue',
                    'sub_structs': {}
                }
            elif def_schema.get('type', "") == "string" and 'knownValues' in def_schema:
                enum_name = f"{self.convert_to_camel_case(name)}"
                if enum_name not in self.generated_tokens:
                    known_values = def_schema['knownValues']
                    self.generate_enum_from_known_values(enum_name, known_values, self.token_descriptions)


        lex_definitions_code = self.lex_definitions_template.render(
            lex_definitions=lex_definitions,
            lexicon_id=self.lexicon_id  # Pass lexicon_id here
    )


        # Combine tokens and enums with other lex definitions
        return lex_definitions_code


    def generate_record_struct(self):
        if 'record' not in self.main_def:
            return ""
        record_schema = self.main_def['record']
        current_struct_name = self.struct_name 
        properties = self.generate_properties(record_schema.get('properties', {}), record_schema.get('required', []), current_struct_name)
        return self.record_template.render(struct_name=self.struct_name, properties=properties, conformance=": ATProtocolCodable, ATProtocolValue")

    def handle_main_def(self):
        main_def = self.defs.get('main', {})
        main_def_type = main_def.get('type')
        
        if main_def_type == 'object':
            return self.handle_object_type(main_def)
        elif main_def_type == 'procedure':
            return self.handle_procedure_type(main_def)
        # Add additional elif blocks for other types as needed
        else:
            return main_def

    def handle_object_type(self, main_def):
        # Handle object-specific logic here
        return main_def

    def handle_procedure_type(self, main_def):
        # Handle procedure-specific logic here
        return main_def
    
    def generate_all_enums(self):
        main_def = self.defs.get("main", {})
        current_struct_name = self.struct_name  # 'main' corresponds to the root struct
        properties = main_def.get('properties', {})

        for prop_name, prop_schema in properties.items():
            if prop_schema.get('type') == 'union':
                union_name = self.convert_to_camel_case(prop_name)
                refs = [self.convert_ref(r) for r in prop_schema['refs']]
                self.generate_enum_for_union(current_struct_name, union_name, refs)
            elif prop_schema.get('type') == 'array':
                item_schema = prop_schema.get('items', {})
                if item_schema.get('type') == 'union':
                    union_name = f"{current_struct_name}{self.convert_to_camel_case(prop_name)}Union"
                    refs = [self.convert_ref(r) for r in item_schema['refs']]
                    self.generate_enum_for_union_array(current_struct_name, prop_name, refs)

    def convert(self) -> str:
        try:
            # Initialize placeholders for different parts of the Swift code
            query_parameters = ""
            input_struct = ""
            output_struct = ""
            errors_enum = ""
            lex_definitions = ""
            record_struct = ""
            main_properties = ""
            procedure=""
            query=""
            conformance=""

            # Check if this is a `*.defs` file (i.e., no "main" definition)
            if 'main' not in self.defs:
                lex_definitions = self.generate_lex_definitions()
            else:
                # Check the type of the main definition
                main_def_type = self.main_def.get('type')
                if main_def_type == 'object':
                    lex_definitions = self.generate_lex_definitions()
                    main_properties = self.properties_template.render(properties=self.generate_properties(self.main_def.get('properties', {}), self.main_def.get('required', []), self.convert_to_camel_case(self.lexicon_id)))
                    conformance=": ATProtocolCodable, ATProtocolValue"
                elif main_def_type == 'record':
                    record_struct = self.generate_record_struct()
                    lex_definitions = self.generate_lex_definitions()
                    conformance=": ATProtocolCodable, ATProtocolValue"
                elif main_def_type == 'query':
                    query_parameters = self.generate_query_parameters(self.main_def.get('parameters'))
                    output_struct = self.generate_output_struct(self.main_def.get('output'))
                    errors_enum = self.generate_errors_enum(self.main_def.get('errors'))
                    lex_definitions = self.generate_lex_definitions()
                    query = self.generate_query_function(lexicon_id=self.lexicon_id, main_def=self.main_def)
                elif main_def_type == 'procedure':
                    input_struct = self.generate_input_struct(self.main_def.get('input'))
                    output_struct = self.generate_output_struct(self.main_def.get('output'))
                    errors_enum = self.generate_errors_enum(self.main_def.get('errors'))
                    lex_definitions = self.generate_lex_definitions()
                    procedure = self.generate_procedure_function(lexicon_id=self.lexicon_id, main_def=self.main_def)
            self.generate_all_enums()
            # Filling in the main template
            swift_code = self.main_template.render(
                is_blob_upload=self.is_blob_upload,
                enums=self.enums,
                lexicon_version=self.lexicon_version, 
                lexicon_id=self.lexicon_id, 
                description=self.description, 
                struct_name=self.struct_name, 
                query_parameters=query_parameters,
                input_struct=input_struct,
                output_struct=output_struct,
                errors_enum=errors_enum,
                lex_definitions=lex_definitions,
                record_struct=record_struct,
                main_properties=main_properties,  
                procedure=procedure,
                query=query,
                conformance=conformance
            )
            
            pretty_swift_code = self.post_process_swift_code(swift_code)
            
            return pretty_swift_code
        except Exception as e:
            import traceback
            return f"An error occurred during the Swift code generation: {str(e)}\n{traceback.format_exc()}"

def convert_json_to_swift(json_content: str) -> str:
    lexicon = json.loads(json_content)
    generator = SwiftCodeGenerator(lexicon)
    return generator.convert()


"""To print a single file  
# Read JSON content from a file
file_path = '/atproto-main/lexicons/app/bsky/embed/external.json'
with open(file_path, 'r') as file:
    json_content = file.read()

# Convert JSON to Swift
swift_code = convert_json_to_swift(json_content)
print(swift_code)
"""



def convert_to_camel_case(name: str) -> str:
    """Converts a string to CamelCase, ignoring empty parts and removing dots."""
    parts = name.split('.')
    return ''.join(part[0].upper() + part[1:] for part in parts if part)

def convert_ref(ref: str) -> str:
    """Converts a reference to Swift format."""
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



def generate_swift_from_lexicons_recursive(folder_path: str, output_folder: str):
    type_dict = {}
    namespace_hierarchy = {}

    # Check if the output folder exists, create it if it doesn't
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
    
    def process_lexicon(filepath):
        with open(filepath, 'r') as f:
            lexicon = json.load(f)
            lexicon_id = lexicon.get('id', '')

            # Skip files where lexicon_id contains 'subscribe'
            if 'subscribe' in lexicon_id:
                return

            defs = lexicon.get('defs', {})

            # Extract and organize the namespace information
            namespace_parts = lexicon_id.split('.')[:3]
            current_level = namespace_hierarchy
            for part in namespace_parts:
                if part not in current_level:
                    current_level[part] = {}
                current_level = current_level[part]


            # Process types for the type dictionary
            for type_name, type_info in defs.items():
                type_kind = type_info.get('type', '')
                swift_lex_id = convert_to_camel_case(lexicon_id)
                swift_type_name = "." + convert_ref(type_name) if type_name != 'main' else ""
                if type_kind in ['object', 'record', 'union', 'array']:
                    type_key = f"{lexicon_id}#{type_name}" if type_name != 'main' else lexicon_id
                    type_dict[type_key] = f"{swift_lex_id}{swift_type_name}"

            # Convert JSON to Swift
            swift_code = SwiftCodeGenerator(lexicon).convert()

            # Define the output file name and save the Swift code
            output_filename = f"{convert_to_camel_case(lexicon_id)}.swift"
            output_file_path = os.path.join(output_folder, output_filename)
            with open(output_file_path, 'w') as swift_file:
                swift_file.write(swift_code)

    # Process lexicons concurrently with threads
    with concurrent.futures.ThreadPoolExecutor() as executor:
        for root, dirs, files in os.walk(folder_path):
            for filename in files:
                if filename.endswith('.json'):
                    filepath = os.path.join(root, filename)
                    executor.submit(process_lexicon, filepath)

    # Generate the type factory code using the type dictionary
    type_factory_code = generate_ATProtocolValueContainer_enum(type_dict)

    # Generate Swift classes from the namespace hierarchy
    swift_namespace_classes = generate_swift_namespace_classes(namespace_hierarchy)
    atproto_client = render_atproto_client(swift_namespace_classes)

    # Save the type factory code to a Swift file
    type_factory_file_path = os.path.join(output_folder, 'ATProtocolValueContainer.swift')
    with open(type_factory_file_path, 'w') as type_factory_file:
        type_factory_file.write(type_factory_code)

    # Save the generated client classes to a Swift file
    class_factory_file_path = os.path.join(output_folder, 'ATProtoClientGeneratedMain.swift')
    with open(class_factory_file_path, 'w') as class_factory_file:
        class_factory_file.write(atproto_client)

def render_atproto_client(generated_classes):
    script_dir = os.path.dirname(os.path.realpath(__file__))
    templates_dir = os.path.join(script_dir, 'templates')
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(templates_dir))
    template = env.get_template('ATProtoClientGeneratedMain.jinja')

    rendered_code = template.render(generated_classes=generated_classes)
    return rendered_code

def generate_ATProtocolValueContainer_enum(type_dict):
    script_dir = os.path.dirname(os.path.realpath(__file__))
    templates_dir = os.path.join(script_dir, 'templates')
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(templates_dir))
    template = env.get_template('ATProtocolValueContainer.jinja')
    type_cases = []
    for type_key, swift_type in type_dict.items():
        type_cases.append((type_key, swift_type))
    
    # Render the template with the type_cases data
    json_value_enum_code = template.render(type_cases=type_cases)
    return json_value_enum_code

def generate_swift_namespace_classes(namespace_hierarchy, network_manager="NetworkManaging", depth=0):
    swift_code = ""
    indent = "    " * depth

    # Generate top-level namespaces as lazy vars in ATProtoClient
    if depth == 0:
        for namespace, sub_hierarchy in namespace_hierarchy.items():
            namespace_class = convert_to_camel_case(namespace)
            swift_code += f"public lazy var {namespace.lower()}: {namespace_class} = {{\n"
            swift_code += f"    return {namespace_class}(networkManager: self.networkManager)\n}}()\n\n"
            # Also generate the top-level class definition
            swift_code += f"public final class {namespace_class}: @unchecked Sendable {{\n"
            swift_code += f"    internal let networkManager: NetworkManaging\n"
            swift_code += f"    internal init(networkManager: NetworkManaging) {{\n"
            swift_code += f"        self.networkManager = networkManager\n    }}\n\n"
            # Recursively generate nested classes and their lazy vars within this top-level class
            swift_code += generate_swift_namespace_classes(sub_hierarchy, network_manager, depth + 1)
            swift_code += "}\n\n"
    else:
        # Generate nested classes and their lazy vars
        for namespace, sub_namespaces in namespace_hierarchy.items():
            class_name = convert_to_camel_case(namespace)
            # Correction: Generate a lazy var for this namespace in its parent
            swift_code += f"{indent}public lazy var {namespace.lower()}: {class_name} = {{\n"
            swift_code += f"{indent}    return {class_name}(networkManager: self.networkManager)\n{indent}}}()\n\n"
            swift_code += f"{indent}public final class {class_name}: @unchecked Sendable {{\n"
            swift_code += f"{indent}    internal let networkManager: NetworkManaging\n"
            swift_code += f"{indent}    internal init(networkManager: NetworkManaging) {{\n"
            swift_code += f"{indent}        self.networkManager = networkManager\n{indent}    }}\n\n"
            # Recurse for any further nested namespaces
            if sub_namespaces:  # Check if there are further nested namespaces
                swift_code += generate_swift_namespace_classes(sub_namespaces, network_manager, depth + 1)
            swift_code += f"{indent}}}\n\n"

    return swift_code



def main(input_dir, output_dir):
    generate_swift_from_lexicons_recursive(input_dir, output_dir)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: script.py <input_dir> <output_dir>")
        sys.exit(1)

    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    main(input_dir, output_dir)
