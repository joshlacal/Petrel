import json
from typing import Dict, List, Any, Optional
from utils import convert_to_camel_case, convert_ref, lowercase_first_letter
from templates import TemplateManager
from enum_generator import EnumGenerator
from type_converter import TypeConverter

class SwiftCodeGenerator:
    def __init__(self, lexicon: Dict[str, Any], cycle_detector=None):
        self.lexicon = lexicon
        self.defs = lexicon.get('defs', {})
        self.lexicon_id = lexicon.get('id', '')
        self.lexicon_version = lexicon.get('lexicon', 1)
        top_level_description = lexicon.get('description', '')
        nested_description = lexicon.get('defs', {}).get('main', {}).get('description', '')
        self.description = f"{top_level_description} {nested_description}".strip()
        self.struct_name = convert_to_camel_case(self.lexicon_id)
        self.conformance = ""
        self.enums = ""
        self.generated_unions = set()
        self.enum_definitions = {}
        self.is_blob_upload = self.check_if_blob_upload(lexicon)
        self.cycle_detector = cycle_detector

        self.token_descriptions = {}
        self.generated_tokens = set()

        self.template_manager = TemplateManager()
        self.enum_generator = EnumGenerator(self)
        self.type_converter = TypeConverter(self)

        self.main_def = self.handle_main_def()

    def check_if_blob_upload(self, lexicon: Dict[str, Any]) -> bool:
        main_def = lexicon.get('defs', {}).get('main', {})
        encoding = main_def.get('input', {}).get('encoding', '')
        return main_def.get('type') == 'procedure' and encoding == '*/*'

    def handle_main_def(self):
        main_def = self.defs.get('main', {})
        main_def_type = main_def.get('type')
        
        if main_def_type == 'object':
            return self.handle_object_type(main_def)
        elif main_def_type == 'procedure':
            return self.handle_procedure_type(main_def)
        elif main_def_type == 'subscription':
            return self.handle_subscription_type(main_def)
        else:
            return main_def

    def handle_object_type(self, main_def):
        return main_def

    def handle_procedure_type(self, main_def):
        return main_def

    def handle_subscription_type(self, main_def):
        return main_def

    def generate_properties(self, properties, required_fields, current_struct_name):
        swift_properties = []
        for name, prop in properties.items():
            swift_type = self.type_converter.determine_swift_type(name, prop, required_fields, current_struct_name)
            description = prop.get('description', '')
            is_optional = name not in required_fields

            # Check if this property should be boxed to break a circular reference
            should_box = False
            if self.cycle_detector:
                # Build the full Swift type name for checking
                swift_full_type = convert_to_camel_case(self.lexicon_id)
                if current_struct_name != convert_to_camel_case(self.lexicon_id):
                    swift_full_type = f"{swift_full_type}.{current_struct_name}"
                should_box = self.cycle_detector.should_box_property(swift_full_type, name)

            swift_properties.append({
                'name': name,
                'type': swift_type,
                'optional': is_optional,
                'description': description,
                'boxed': should_box
            })
        return swift_properties

    def generate_query_parameters(self, parameters: Optional[Dict[str, Any]]) -> str:
        if not parameters:
            return ""
        properties = self.generate_properties(parameters['properties'], parameters.get('required', []), "Parameters")
        return self.template_manager.query_parameters_template.render(properties=properties)

    def generate_input_struct(self, input_obj: Optional[Dict[str, Any]]) -> str:
        if not input_obj:
            return ""
        
        encoding = input_obj.get('encoding', '')
        
        # Handle input with encoding but no schema (like CAR files)
        if 'schema' not in input_obj:
            if encoding != '' and encoding != 'application/json':
                properties = [{"name": "data", "type": "Data", "optional": False}]
                conformance = ""
                return self.template_manager.input_struct_template.render(properties=properties, conformance=conformance)
            else:
                return ""
        
        input_schema = input_obj['schema']
        conformance = ": ATProtocolCodable" if encoding == "application/json" else ""

        properties = ""
        if encoding != '' and encoding != 'application/json':
            properties = [{"name": "data", "type": "Data", "optional": False}]
        elif input_schema.get('type') == 'ref':
            ref_type = convert_ref(input_schema['ref'])
            properties = [{"name": "data", "type": ref_type, "optional": False}]
        else:
            properties = self.generate_properties(input_schema.get('properties', {}), input_schema.get('required', []), "Input")

        return self.template_manager.input_struct_template.render(properties=properties, conformance=conformance)

    def generate_output_struct(self, output_obj: Optional[Dict[str, Any]]) -> str:
        if not output_obj:
            return ""

        encoding = output_obj.get('encoding', '')
        output_schema = output_obj.get('schema', {})

        context = {
            'conformance': ": ATProtocolCodable" if encoding == "application/json" else "",
            'is_type_alias': False,
            'properties': [],
            'type_alias_target': None,
        }

        if output_schema.get('type') == 'ref':
            context['is_type_alias'] = True
            context['type_alias_target'] = convert_ref(output_schema['ref'])
        elif encoding == "*/*":
            context['properties'] = [{"name": "data", "type": "Data", "optional": False}]
        elif not output_schema or (not output_schema.get('properties') and output_schema.get('type') != 'object'):
            # No schema or schema without properties (binary data case)
            # For encodings like application/vnd.ipld.car, application/jsonl without schema
            if encoding and encoding != 'application/json':
                context['properties'] = [{"name": "data", "type": "Data", "optional": False}]
            else:
                context['properties'] = []
        else:
            context['properties'] = self.generate_properties(output_schema.get('properties', {}), output_schema.get('required', []), "Output")

        return self.template_manager.output_struct_template.render(**context)

    def generate_errors_enum(self, errors: Optional[List[Dict[str, str]]]) -> str:
        if not errors:
            return ""
        return self.template_manager.errors_enum_template.render(errors=errors)

    def generate_message_union(self, message_obj: Optional[Dict[str, Any]]) -> str:
        if not message_obj:
            return ""
        
        schema = message_obj.get('schema', {})
        if schema.get('type') != 'union':
            return ""
        
        refs = schema.get('refs', [])
        variants = []
        
        for ref in refs:
            # Convert ref to Swift type and case name
            if ref.startswith('#'):
                # Local reference
                ref_name = ref[1:]
                type_name = convert_to_camel_case(ref_name)
                type_id = f"{self.lexicon_id}#{ref_name}"
            else:
                # External reference
                type_name = convert_ref(ref)
                type_id = ref
            
            # Create a case name from the type
            case_name = type_name.split('.')[-1]
            case_name = case_name[0].lower() + case_name[1:] if case_name else case_name
            
            variants.append({
                'case_name': case_name,
                'type': type_name,
                'type_id': type_id
            })
        
        return self.template_manager.message_union_template.render(variants=variants)

    def is_union_array(self, def_schema):
        return def_schema.get('type') == 'array' and 'refs' in def_schema.get('items', {})

    def generate_lex_definitions(self):
        lex_definitions = {}
        for name, def_schema in self.defs.items():
            current_struct_name = convert_to_camel_case(name)
            
            if self.is_union_array(def_schema):
                refs = def_schema['items']['refs']
                self.enum_generator.generate_enum_for_union_array(current_struct_name, name, refs)
                continue
            if name != 'main' and def_schema.get('type', "") == "object":
                conformance = ": ATProtocolCodable, ATProtocolValue"
                properties = self.generate_properties(def_schema.get('properties', {}), def_schema.get('required', []), current_struct_name)
                
                sub_structs = {}
                for key, value in def_schema.items():
                    if key not in ['properties', 'required', 'type', 'description', 'nullable']:
                        # Only process if value is a dictionary (sub-object schema)
                        if isinstance(value, dict) and 'properties' in value:
                            sub_conformance = ": ATProtocolCodable, ATProtocolValue"
                            sub_properties = self.generate_properties(value.get('properties', {}), value.get('required', []), convert_to_camel_case(key))
                            sub_structs[convert_to_camel_case(key)] = {
                                'properties': sub_properties, 
                                'conformance': sub_conformance
                            }
                
                lex_definitions[convert_to_camel_case(name)] = {
                    'properties': properties, 
                    'conformance': conformance,
                    'sub_structs': sub_structs
                }
            elif def_schema.get('type', '') == "array" and def_schema.get('items', {}).get('type', '') == 'union':
                union_array_name = convert_to_camel_case(name) + ""
                refs = def_schema['items'].get('refs', [])
                self.enum_generator.generate_enum_for_union_array(current_struct_name, union_array_name, refs)
                properties = [{
                    'name': lowercase_first_letter(name),
                    'type': f'[{union_array_name}]',
                    'optional': False
                }]
                lex_definitions[union_array_name] = {
                    'properties': properties,
                    'conformance': ': ATProtocolCodable, ATProtocolValue',
                    'sub_structs': {}
                }
            elif def_schema.get('type', "") == "string" and 'knownValues' in def_schema:
                enum_name = f"{convert_to_camel_case(name)}"
                if enum_name not in self.generated_tokens:
                    known_values = def_schema['knownValues']
                    self.enum_generator.generate_enum_from_known_values(enum_name, known_values, self.token_descriptions)

        return self.template_manager.lex_definitions_template.render(
            lex_definitions=lex_definitions,
            lexicon_id=self.lexicon_id
        )

    def generate_record_struct(self):
        if 'record' not in self.main_def:
            return ""
        record_schema = self.main_def['record']
        current_struct_name = self.struct_name 
        properties = self.generate_properties(record_schema.get('properties', {}), record_schema.get('required', []), current_struct_name)
        return self.template_manager.record_template.render(struct_name=self.struct_name, properties=properties, conformance=": ATProtocolCodable, ATProtocolValue")

    def generate_all_enums(self):
        main_def = self.defs.get("main", {})
        current_struct_name = self.struct_name
        properties = main_def.get('properties', {})

        for prop_name, prop_schema in properties.items():
            if prop_schema.get('type') == 'union':
                union_name = convert_to_camel_case(prop_name)
                refs = [convert_ref(r) for r in prop_schema['refs']]
                self.enum_generator.generate_enum_for_union(current_struct_name, union_name, refs)
            elif prop_schema.get('type') == 'array':
                item_schema = prop_schema.get('items', {})
                if item_schema.get('type') == 'union':
                    union_name = f"{current_struct_name}{convert_to_camel_case(prop_name)}Union"
                    refs = [convert_ref(r) for r in item_schema['refs']]
                    self.enum_generator.generate_enum_for_union_array(current_struct_name, prop_name, refs)

    def convert(self) -> str:
        try:
            query_parameters = ""
            input_struct = ""
            output_struct = ""
            errors_enum = ""
            lex_definitions = ""
            record_struct = ""
            main_properties = ""
            procedure = ""
            query = ""
            subscription = ""
            message_union = ""
            conformance = ""

            if 'main' not in self.defs:
                lex_definitions = self.generate_lex_definitions()
            else:
                main_def_type = self.main_def.get('type')
                if main_def_type == 'object':
                    lex_definitions = self.generate_lex_definitions()
                    main_properties = self.template_manager.properties_template.render(properties=self.generate_properties(self.main_def.get('properties', {}), self.main_def.get('required', []), convert_to_camel_case(self.lexicon_id)))
                    conformance = ": ATProtocolCodable, ATProtocolValue"
                elif main_def_type == 'record':
                    record_struct = self.generate_record_struct()
                    lex_definitions = self.generate_lex_definitions()
                    conformance = ": ATProtocolCodable, ATProtocolValue"
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
                elif main_def_type == 'subscription':
                    query_parameters = self.generate_query_parameters(self.main_def.get('parameters'))
                    message_union = self.generate_message_union(self.main_def.get('message'))
                    errors_enum = self.generate_errors_enum(self.main_def.get('errors'))
                    lex_definitions = self.generate_lex_definitions()
                    subscription = self.generate_subscription_function(lexicon_id=self.lexicon_id, main_def=self.main_def)
            self.generate_all_enums()
            
            swift_code = self.template_manager.main_template.render(
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
                subscription=subscription,
                message_union=message_union,
                conformance=conformance
            )
            
            return self.post_process_swift_code(swift_code)
        except Exception as e:
            import traceback
            return f"An error occurred during the Swift code generation: {str(e)}\n{traceback.format_exc()}"

    @staticmethod
    def post_process_swift_code(code: str) -> str:
        code = code.replace('public struct ', '\npublic struct ')
        code = code.replace('public enum ', '\npublic enum ')
        return code.lstrip()

    def generate_query_function(self, lexicon_id, main_def):
        # Split the lexicon ID to determine the namespace
        template_namespace_parts = lexicon_id.split('.')[:-1]
        template_namespace_name = '.'.join(convert_to_camel_case(part) for part in template_namespace_parts)
        
        # Determine the query name by converting the last part of the lexicon ID to CamelCase
        query_name = convert_to_camel_case(lexicon_id.split('.')[-1])
                
        # Determine if the query has input parameters
        has_input = 'parameters' in main_def
        input_struct_name = convert_to_camel_case(lexicon_id) + ".Parameters" if has_input else None
        output_type = convert_to_camel_case(lexicon_id) + ".Output" if 'output' in main_def else None
        
        input_parameters = ''
        input_values = ''
        
        if has_input:
            input_params = main_def.get('parameters', {}).get('properties', {})
            input_parameters = ', '.join([
                f"{param}: {self.type_converter.determine_swift_type(param, details, main_def.get('parameters', {}).get('required', []), param)}" 
                for param, details in input_params.items()
            ])
            input_values = ', '.join([f"{param}: {param}" for param in input_params.keys()])
        
        # Define the API endpoint
        endpoint = f"{lexicon_id}"
        
        # Extract the output encoding, defaulting to 'application/json' if not specified
        output_encoding = main_def.get('output', {}).get('encoding', 'application/json')
        
        # Render the query template with the encoding information
        return self.template_manager.query_template.render(
            template_namespace_name=template_namespace_name,
            query_name=query_name,
            input_parameters=input_parameters,
            input_struct_name=input_struct_name,
            input_values=input_values,
            output_type=output_type,
            endpoint=endpoint,
            description=self.description,
            output_encoding=output_encoding,  # Pass the output encoding to the template
            has_errors='errors' in main_def and main_def['errors'],  # Check if errors are defined
            struct_name=convert_to_camel_case(lexicon_id)  # Pass struct name for error type reference
        )

    def generate_procedure_function(self, lexicon_id, main_def):
        # Split the lexicon ID to determine the namespace
        template_namespace_parts = lexicon_id.split('.')[:-1]
        template_namespace_name = '.'.join(convert_to_camel_case(part) for part in template_namespace_parts)
        
        # Determine the procedure name by converting the last part of the lexicon ID to CamelCase
        procedure_name = convert_to_camel_case(lexicon_id.split('.')[-1])
                
        # Determine if the procedure is a blob upload based on the input encoding
        input_encoding = main_def.get('input', {}).get('encoding', '') if 'input' in main_def else None
        is_blob_upload = 'input' in main_def and input_encoding == '*/*'
        is_binary_data = 'input' in main_def and input_encoding != '' and input_encoding != 'application/json' and input_encoding != '*/*'
        
        input_parameters = ''
        input_values = ''
        input_struct_name = None
        
        # Extract input and output encodings, defaulting to 'application/json' if not specified
        input_encoding = main_def.get('input', {}).get('encoding', 'application/json') if 'input' in main_def else None
        output_encoding = main_def.get('output', {}).get('encoding', 'application/json') if 'output' in main_def else None
        
        if 'input' in main_def and 'schema' in main_def['input']:
            input_params = main_def['input']['schema'].get('properties', {})
            current_struct_name = convert_to_camel_case(lexicon_id)
            
            input_parameters = ', '.join([
                f"{param}: {self.type_converter.determine_swift_type(param, details, main_def['input'].get('required', []), current_struct_name)}" 
                for param, details in input_params.items()
            ])
            input_values = ', '.join([f"{param}: {param}" for param in input_params.keys()])
            input_struct_name = convert_to_camel_case(lexicon_id) + ".Input"
        
        # Define the API endpoint
        endpoint = f"{lexicon_id}"
        
        # Render the procedure template with the encoding information
        return self.template_manager.procedure_template.render(
            template_namespace_name=template_namespace_name,
            procedure_name=procedure_name,
            input_parameters=input_parameters,
            input_struct_name=input_struct_name,
            input_values=input_values,
            output_type=convert_to_camel_case(lexicon_id) + ".Output" if 'output' in main_def else None,
            endpoint=endpoint,
            description=self.description,
            is_blob_upload=is_blob_upload,
            is_binary_data=is_binary_data,
            input_encoding=input_encoding,    # Pass the input encoding to the template
            output_encoding=output_encoding,   # Pass the output encoding to the template
            has_errors='errors' in main_def and main_def['errors'],  # Check if errors are defined
            struct_name=convert_to_camel_case(lexicon_id)  # Pass struct name for error type reference
        )

    def generate_subscription_function(self, lexicon_id, main_def):
        # Split the lexicon ID to determine the namespace
        template_namespace_parts = lexicon_id.split('.')[:-1]
        template_namespace_name = '.'.join(convert_to_camel_case(part) for part in template_namespace_parts)
        
        # Determine the subscription name by converting the last part of the lexicon ID to camelCase
        subscription_name = convert_to_camel_case(lexicon_id.split('.')[-1])
        # Make first letter lowercase for method name
        subscription_name = subscription_name[0].lower() + subscription_name[1:] if subscription_name else subscription_name
        
        # Determine if the subscription has input parameters
        has_parameters = 'parameters' in main_def
        input_struct_name = convert_to_camel_case(lexicon_id) + ".Parameters" if has_parameters else None
        
        # Get the message type
        message_type = convert_to_camel_case(lexicon_id) + ".Message"
        
        input_parameters = ''
        input_values = ''
        
        if has_parameters:
            input_params = main_def.get('parameters', {}).get('properties', {})
            required_params = main_def.get('parameters', {}).get('required', [])
            
            # Build parameter list with proper optionality and defaults
            param_list = []
            value_list = []
            for param, details in input_params.items():
                swift_type = self.type_converter.determine_swift_type(param, details, required_params, param)
                is_optional = param not in required_params
                
                # Add default value for optional parameters
                if is_optional:
                    param_list.append(f"{param}: {swift_type}? = nil")
                else:
                    param_list.append(f"{param}: {swift_type}")
                value_list.append(f"{param}: {param}")
            
            input_parameters = ', '.join(param_list)
            input_values = ', '.join(value_list)
        
        # Define the API endpoint
        endpoint = f"{lexicon_id}"
        
        # Render the subscription template
        return self.template_manager.subscription_template.render(
            template_namespace_name=template_namespace_name,
            subscription_name=subscription_name,
            has_parameters=has_parameters,
            input_parameters=input_parameters,
            input_struct_name=input_struct_name,
            input_values=input_values,
            message_type=message_type,
            endpoint=endpoint,
            description=self.description
        )

def convert_json_to_swift(json_content: str) -> str:
    lexicon = json.loads(json_content)
    generator = SwiftCodeGenerator(lexicon)
    return generator.convert()
