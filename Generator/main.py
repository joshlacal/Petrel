import orjson
import sys
import os
import asyncio
import aiofiles
from swift_code_generator import SwiftCodeGenerator, convert_json_to_swift
from utils import convert_to_camel_case
from cycle_detector import CycleDetector

async def generate_swift_from_lexicons_recursive(folder_path: str, output_folder: str):
    type_dict = {}
    namespace_hierarchy = {}
    cycle_detector = CycleDetector()
    lexicons = []  # Store all lexicons for two-pass processing

    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # First pass: Load all lexicons and build dependency graph
    for root, dirs, files in os.walk(folder_path):
        for filename in files:
            if filename.endswith('.json'):
                filepath = os.path.join(root, filename)
                async with aiofiles.open(filepath, 'rb') as f:
                    content = await f.read()
                    lexicon = orjson.loads(content)
                    lexicon_id = lexicon.get('id', '')

                    if 'subscribe' in lexicon_id or 'ozone' in lexicon_id:
                        continue

                    lexicons.append((filepath, lexicon))

                    # Register types with cycle detector
                    defs = lexicon.get('defs', {})
                    for def_name, def_schema in defs.items():
                        cycle_detector.add_type(lexicon_id, def_name, def_schema)

                    # Also register query/procedure output unions
                    main_def = defs.get('main', {})
                    if main_def.get('type') in ['query', 'procedure']:
                        output_schema = main_def.get('output', {}).get('schema', {})
                        if output_schema.get('type') == 'object':
                            cycle_detector.add_output_type(lexicon_id, output_schema)

    # Detect circular dependencies
    cycle_detector.detect_cycles()

    # Debug output
    print(f"Loaded {len(cycle_detector.type_properties)} types, {len(cycle_detector.union_variants)} unions")

    # Debug: show some union examples
    union_list = list(cycle_detector.union_variants.keys())
    if union_list:
        print(f"Sample unions: {union_list[:3]}")

    if cycle_detector.circular_properties:
        print(f"Detected {len(cycle_detector.circular_properties)} circular properties:")
        for type_name, prop_name in cycle_detector.circular_properties:
            print(f"  - {type_name}.{prop_name}")
    if cycle_detector.indirect_enums:
        print(f"Detected {len(cycle_detector.indirect_enums)} indirect enums:")
        for enum_name in cycle_detector.indirect_enums:
            print(f"  - {enum_name}")
    else:
        print("No indirect enums detected")

    async def process_lexicon(filepath, lexicon):
        lexicon_id = lexicon.get('id', '')
        defs = lexicon.get('defs', {})

        namespace_parts = lexicon_id.split('.')[:3]
        current_level = namespace_hierarchy
        for part in namespace_parts:
            if part not in current_level:
                current_level[part] = {}
            current_level = current_level[part]

        for type_name, type_info in defs.items():
            type_kind = type_info.get('type', '')
            swift_lex_id = convert_to_camel_case(lexicon_id)
            swift_type_name = "." + convert_to_camel_case(type_name) if type_name != 'main' else ""
            if type_kind in ['object', 'record', 'union', 'array']:
                type_key = f"{lexicon_id}#{type_name}" if type_name != 'main' else lexicon_id
                type_dict[type_key] = f"{swift_lex_id}{swift_type_name}"

        swift_code = SwiftCodeGenerator(lexicon, cycle_detector).convert()

        output_filename = f"{convert_to_camel_case(lexicon_id)}.swift"
        output_file_path = os.path.join(output_folder, output_filename)
        async with aiofiles.open(output_file_path, 'w') as swift_file:
            await swift_file.write(swift_code)

    # Second pass: Generate code with cycle information
    tasks = []
    for filepath, lexicon in lexicons:
        tasks.append(asyncio.create_task(process_lexicon(filepath, lexicon)))

    await asyncio.gather(*tasks)

    type_factory_code = generate_ATProtocolValueContainer_enum(type_dict)
    swift_namespace_classes = generate_swift_namespace_classes(namespace_hierarchy)
    atproto_client = render_atproto_client(swift_namespace_classes)

    type_factory_file_path = os.path.join(output_folder, 'ATProtocolValueContainer.swift')
    async with aiofiles.open(type_factory_file_path, 'w') as type_factory_file:
        await type_factory_file.write(type_factory_code)

    class_factory_file_path = os.path.join(output_folder, 'ATProtoClientGeneratedMain.swift')
    async with aiofiles.open(class_factory_file_path, 'w') as class_factory_file:
        await class_factory_file.write(atproto_client)

def render_atproto_client(generated_classes):
    from templates import TemplateManager
    template_manager = TemplateManager()
    template = template_manager.env.get_template('ATProtoClientGeneratedMain.jinja')
    rendered_code = template.render(generated_classes=generated_classes)
    return rendered_code

def generate_ATProtocolValueContainer_enum(type_dict):
    from templates import TemplateManager
    template_manager = TemplateManager()
    template = template_manager.env.get_template('ATProtocolValueContainer.jinja')
    type_cases = []
    for type_key, swift_type in type_dict.items():
        type_cases.append((type_key, swift_type))
    
    json_value_enum_code = template.render(type_cases=type_cases)
    return json_value_enum_code

def generate_swift_namespace_classes(namespace_hierarchy, network_manager="NetworkService", depth=0):
    swift_code = ""
    indent = "    " * depth

    if depth == 0:
        for namespace, sub_hierarchy in namespace_hierarchy.items():
            namespace_class = convert_to_camel_case(namespace)
            swift_code += f"public lazy var {namespace.lower()}: {namespace_class} = {{\n"
            swift_code += f"    return {namespace_class}(networkService: self.networkService)\n}}()\n\n"
            swift_code += f"public final class {namespace_class}: @unchecked Sendable {{\n"
            swift_code += f"    internal let networkService: NetworkService\n"
            swift_code += f"    internal init(networkService: NetworkService) {{\n"
            swift_code += f"        self.networkService = networkService\n    }}\n\n"
            swift_code += generate_swift_namespace_classes(sub_hierarchy, network_manager, depth + 1)
            swift_code += "}\n\n"
    else:
        for namespace, sub_namespaces in namespace_hierarchy.items():
            class_name = convert_to_camel_case(namespace)
            swift_code += f"{indent}public lazy var {namespace.lower()}: {class_name} = {{\n"
            swift_code += f"{indent}    return {class_name}(networkService: self.networkService)\n{indent}}}()\n\n"
            swift_code += f"{indent}public final class {class_name}: @unchecked Sendable {{\n"
            swift_code += f"{indent}    internal let networkService: NetworkService\n"
            swift_code += f"{indent}    internal init(networkService: NetworkService) {{\n"
            swift_code += f"{indent}        self.networkService = networkService\n{indent}    }}\n\n"
            if sub_namespaces:
                swift_code += generate_swift_namespace_classes(sub_namespaces, network_manager, depth + 1)
            swift_code += f"{indent}}}\n\n"

    return swift_code

async def main(input_dir, output_dir):
    await generate_swift_from_lexicons_recursive(input_dir, output_dir)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python main.py <input_dir> <output_dir>")
        sys.exit(1)

    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    asyncio.run(main(input_dir, output_dir))
