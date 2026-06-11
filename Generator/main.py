import orjson
import sys
import os
import asyncio
import aiofiles
from swift_code_generator import SwiftCodeGenerator, convert_json_to_swift
from kotlin_code_generator import KotlinCodeGenerator
from kotlin_type_converter import convert_to_pascal_case
from utils import convert_to_camel_case
from cycle_detector import CycleDetector

def get_namespace_path(lexicon_id: str) -> str:
    """Convert lexicon ID to hierarchical path.
    e.g., 'app.bsky.feed.post' -> 'App/Bsky'
    """
    parts = lexicon_id.split('.')
    if len(parts) >= 2:
        # Capitalize first two parts for directory names
        return '/'.join(part.capitalize() for part in parts[:2])
    return parts[0].capitalize()

DEFAULT_EXCLUDED_NAMESPACES = ('tools.ozone',)

def load_manifest(path):
    """Load a generation manifest (JSON). Paths inside are relative to CWD."""
    with open(path, 'rb') as f:
        return orjson.loads(f.read())

def is_excluded(lexicon_id, exclude_namespaces):
    return any(
        lexicon_id == ns or lexicon_id.startswith(ns + '.')
        for ns in exclude_namespaces
    )

async def load_lexicons(dirs, exclude_namespaces, cycle_detector, emit=True):
    """Load lexicon JSONs from `dirs`, registering all types with `cycle_detector`.

    Returns [(filepath, lexicon)] for code emission when `emit` is true; with
    emit=False (overlay reference set) types are registered for cross-package
    type resolution but no files are returned for generation.
    """
    loaded = []
    for folder_path in dirs:
        for root, dirnames, files in os.walk(folder_path):
            dirnames.sort()   # deterministic traversal so generated output is byte-stable
            files.sort()
            for filename in files:
                if not filename.endswith('.json'):
                    continue
                filepath = os.path.join(root, filename)
                async with aiofiles.open(filepath, 'rb') as f:
                    content = await f.read()
                lexicon = orjson.loads(content)
                lexicon_id = lexicon.get('id', '')

                if is_excluded(lexicon_id, exclude_namespaces):
                    continue

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

                if emit:
                    loaded.append((filepath, lexicon))
    return loaded

async def generate_swift_from_lexicons_recursive(
    folder_path,
    output_folder: str,
    exclude_namespaces=DEFAULT_EXCLUDED_NAMESPACES,
    reference_dirs=(),
):
    type_dict = {}
    namespace_hierarchy = {}
    cycle_detector = CycleDetector()

    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    emit_dirs = folder_path if isinstance(folder_path, (list, tuple)) else [folder_path]

    # First pass: load reference lexicons (type resolution only), then emit set
    await load_lexicons(reference_dirs, exclude_namespaces, cycle_detector, emit=False)
    lexicons = await load_lexicons(emit_dirs, exclude_namespaces, cycle_detector, emit=True)

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

        # Create hierarchical output path based on lexicon namespace
        # e.g., "app.bsky.feed.post" -> "Lexicons/App/Bsky/"
        namespace_path = get_namespace_path(lexicon_id)
        lexicon_output_dir = os.path.join(output_folder, 'Lexicons', namespace_path)
        os.makedirs(lexicon_output_dir, exist_ok=True)

        output_filename = f"{convert_to_camel_case(lexicon_id)}.swift"
        output_file_path = os.path.join(lexicon_output_dir, output_filename)
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

    # Output ATProtocolValueContainer to Core/Types within output folder
    core_types_dir = os.path.join(output_folder, 'Core', 'Types')
    os.makedirs(core_types_dir, exist_ok=True)
    type_factory_file_path = os.path.join(core_types_dir, 'ATProtocolValueContainer.swift')
    async with aiofiles.open(type_factory_file_path, 'w') as type_factory_file:
        await type_factory_file.write(type_factory_code)

    # Output main client file to Client directory within output folder
    client_dir = os.path.join(output_folder, 'Client')
    os.makedirs(client_dir, exist_ok=True)
    class_factory_file_path = os.path.join(client_dir, 'ATProtoClient+Generated.swift')
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

def lower_camel(segment):
    """Lexicon namespace segment -> lowerCamelCase Swift property name.

    Segments are already camelCase in lexicon ids (e.g. authManageLabelerService);
    only the first character needs lowering. The previous .lower() collapsed them
    to unreadable all-lowercase names (authmanagelabelerservice)."""
    return segment[0].lower() + segment[1:] if segment else segment

def generate_swift_namespace_classes(namespace_hierarchy, network_manager="NetworkService", depth=0):
    swift_code = ""
    indent = "    " * depth

    if depth == 0:
        for namespace, sub_hierarchy in namespace_hierarchy.items():
            namespace_class = convert_to_camel_case(namespace)
            prop_name = lower_camel(namespace)
            swift_code += f"public lazy var {prop_name}: {namespace_class} = {{\n"
            swift_code += f"    return {namespace_class}(networkService: self.networkService)\n}}()\n\n"
            if prop_name != namespace.lower():
                swift_code += f"@available(*, deprecated, renamed: \"{prop_name}\")\n"
                swift_code += f"public var {namespace.lower()}: {namespace_class} {{ {prop_name} }}\n\n"
            swift_code += f"public final class {namespace_class}: @unchecked Sendable {{\n"
            swift_code += f"    internal let networkService: NetworkService\n"
            swift_code += f"    internal init(networkService: NetworkService) {{\n"
            swift_code += f"        self.networkService = networkService\n    }}\n\n"
            swift_code += generate_swift_namespace_classes(sub_hierarchy, network_manager, depth + 1)
            swift_code += "}\n\n"
    else:
        for namespace, sub_namespaces in namespace_hierarchy.items():
            class_name = convert_to_camel_case(namespace)
            prop_name = lower_camel(namespace)
            swift_code += f"{indent}public lazy var {prop_name}: {class_name} = {{\n"
            swift_code += f"{indent}    return {class_name}(networkService: self.networkService)\n{indent}}}()\n\n"
            if prop_name != namespace.lower():
                swift_code += f"{indent}@available(*, deprecated, renamed: \"{prop_name}\")\n"
                swift_code += f"{indent}public var {namespace.lower()}: {class_name} {{ {prop_name} }}\n\n"
            swift_code += f"{indent}public final class {class_name}: @unchecked Sendable {{\n"
            swift_code += f"{indent}    internal let networkService: NetworkService\n"
            swift_code += f"{indent}    internal init(networkService: NetworkService) {{\n"
            swift_code += f"{indent}        self.networkService = networkService\n{indent}    }}\n\n"
            if sub_namespaces:
                swift_code += generate_swift_namespace_classes(sub_namespaces, network_manager, depth + 1)
            swift_code += f"{indent}}}\n\n"

    return swift_code

async def generate_kotlin_from_lexicons_recursive(
    folder_path,
    output_folder: str,
    exclude_namespaces=DEFAULT_EXCLUDED_NAMESPACES,
    reference_dirs=(),
):
    """Generate Kotlin code from lexicons."""
    namespace_hierarchy = {}
    cycle_detector = CycleDetector()

    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    print("Generating Kotlin code...")

    emit_dirs = folder_path if isinstance(folder_path, (list, tuple)) else [folder_path]

    # First pass: load reference lexicons (type resolution only), then emit set
    await load_lexicons(reference_dirs, exclude_namespaces, cycle_detector, emit=False)
    lexicons = await load_lexicons(emit_dirs, exclude_namespaces, cycle_detector, emit=True)

    # Detect circular dependencies (less critical for Kotlin but still useful)
    cycle_detector.detect_cycles()

    print(f"Loaded {len(lexicons)} lexicons for Kotlin generation")

    async def process_kotlin_lexicon(filepath, lexicon):
        lexicon_id = lexicon.get('id', '')
        defs = lexicon.get('defs', {})

        # Build namespace hierarchy
        namespace_parts = lexicon_id.split('.')[:3]
        current_level = namespace_hierarchy
        for part in namespace_parts:
            if part not in current_level:
                current_level[part] = {}
            current_level = current_level[part]

        # Generate Kotlin code
        kotlin_code = KotlinCodeGenerator(lexicon, cycle_detector).convert()

        # Create hierarchical output path based on lexicon namespace
        # e.g., "app.bsky.feed.post" -> "lexicons/app/bsky/"
        namespace_path = get_namespace_path(lexicon_id).lower()
        lexicon_output_dir = os.path.join(output_folder, 'lexicons', namespace_path)
        os.makedirs(lexicon_output_dir, exist_ok=True)

        output_filename = f"{convert_to_pascal_case(lexicon_id)}.kt"
        output_file_path = os.path.join(lexicon_output_dir, output_filename)
        async with aiofiles.open(output_file_path, 'w') as kotlin_file:
            await kotlin_file.write(kotlin_code)

    # Second pass: Generate code
    tasks = []
    for filepath, lexicon in lexicons:
        tasks.append(asyncio.create_task(process_kotlin_lexicon(filepath, lexicon)))

    await asyncio.gather(*tasks)

    # Generate namespace classes for Kotlin (inner content only, like Swift)
    kotlin_namespace_classes = generate_kotlin_namespace_classes(namespace_hierarchy)
    kotlin_client = render_kotlin_atproto_client(kotlin_namespace_classes)

    # Output main client file to client directory within output folder
    client_dir = os.path.join(output_folder, 'client')
    os.makedirs(client_dir, exist_ok=True)
    client_main_file_path = os.path.join(client_dir, 'ATProtoClientGenerated.kt')
    async with aiofiles.open(client_main_file_path, 'w') as client_file:
        await client_file.write(kotlin_client)

    print(f"Kotlin generation complete: {len(lexicons)} files generated")


def render_kotlin_atproto_client(generated_classes):
    """Render the Kotlin ATProtoClient using the Jinja template."""
    from templates import TemplateManager
    template_manager = TemplateManager()
    template = template_manager.env.get_template('kotlin/KotlinClientMain.jinja')
    rendered_code = template.render(generated_classes=generated_classes)
    return rendered_code


def generate_kotlin_namespace_classes(namespace_hierarchy, depth=0):
    """Generate Kotlin namespace inner class hierarchy (content only, no class wrapper)."""
    kotlin_code = ""
    indent = "    " * depth

    if depth == 0:
        # Generate only the inner namespace content (injected into template)
        for namespace, sub_hierarchy in namespace_hierarchy.items():
            namespace_class = convert_to_pascal_case(namespace)
            prop_name = lower_camel(namespace)
            kotlin_code += f"    val {prop_name}: {namespace_class} = {namespace_class}()\n\n"
            if prop_name != namespace.lower():
                kotlin_code += f"    @Deprecated(\"Renamed\", ReplaceWith(\"{prop_name}\"))\n"
                kotlin_code += f"    val {namespace.lower()}: {namespace_class} get() = {prop_name}\n\n"
            kotlin_code += f"    inner class {namespace_class} {{\n"
            kotlin_code += f"        val client: ATProtoClient get() = this@ATProtoClient\n"
            kotlin_code += generate_kotlin_namespace_classes(sub_hierarchy, depth + 2)
            kotlin_code += "    }\n\n"
    else:
        for namespace, sub_namespaces in namespace_hierarchy.items():
            class_name = convert_to_pascal_case(namespace)
            prop_name = lower_camel(namespace)
            kotlin_code += f"{indent}val {prop_name}: {class_name} = {class_name}()\n\n"
            if prop_name != namespace.lower():
                kotlin_code += f"{indent}@Deprecated(\"Renamed\", ReplaceWith(\"{prop_name}\"))\n"
                kotlin_code += f"{indent}val {namespace.lower()}: {class_name} get() = {prop_name}\n\n"
            kotlin_code += f"{indent}inner class {class_name} {{\n"
            kotlin_code += f"{indent}    val client: ATProtoClient get() = this@ATProtoClient\n"
            if sub_namespaces:
                kotlin_code += generate_kotlin_namespace_classes(sub_namespaces, depth + 1)
            kotlin_code += f"{indent}}}\n\n"

    return kotlin_code


def _resolve_kotlin_output():
    """Resolve the petrel-kotlin generated source root.

    run.py is always invoked from the Petrel/ repo root (e.g.
    ``python run.py Generator/lexicons Sources/Petrel/Generated --language both``),
    so we anchor the Kotlin output at CWD + petrel-kotlin/src/main/kotlin/com/atproto/generated
    rather than deriving it from output_dir (which used to produce stray
    Sources/Petrel/petrel-kotlin/ trees when dirname() didn't walk up far enough).
    """
    return os.path.join(
        os.getcwd(),
        'petrel-kotlin', 'src', 'main', 'kotlin', 'com', 'atproto', 'generated',
    )


async def run_manifest(manifest_path, language='both'):
    """Generate from a manifest file (see Generator/manifests/*.json)."""
    manifest = load_manifest(manifest_path)
    lex = manifest.get('lexicons', {})
    emit_dirs = lex.get('emit', [])
    reference_dirs = lex.get('reference', [])
    exclude = tuple(lex.get('exclude_namespaces', []))
    kind = manifest.get('package', {}).get('kind', 'core')
    if kind not in ('core', 'overlay'):
        raise ValueError(f"Unknown package.kind '{kind}' in {manifest_path}")
    if kind == 'overlay':
        raise NotImplementedError("overlay manifests are handled in a later stage")

    tasks = []
    swift_cfg = manifest.get('swift')
    if swift_cfg and language in ('swift', 'both'):
        tasks.append(generate_swift_from_lexicons_recursive(
            emit_dirs, swift_cfg['output'],
            exclude_namespaces=exclude, reference_dirs=reference_dirs,
        ))
    kotlin_cfg = manifest.get('kotlin')
    if kotlin_cfg and language in ('kotlin', 'both'):
        tasks.append(generate_kotlin_from_lexicons_recursive(
            emit_dirs, kotlin_cfg['output'],
            exclude_namespaces=exclude, reference_dirs=reference_dirs,
        ))
    await asyncio.gather(*tasks)


async def main(input_dir, output_dir, language='swift'):
    """Main entry point supporting multiple languages (legacy positional CLI)."""
    if language == 'swift':
        await generate_swift_from_lexicons_recursive(input_dir, output_dir)
    elif language == 'kotlin':
        kotlin_output = _resolve_kotlin_output()
        await generate_kotlin_from_lexicons_recursive(input_dir, kotlin_output)
    elif language == 'both':
        # Swift goes directly to output_dir (same as --language swift)
        # Kotlin goes to petrel-kotlin/ package directory
        kotlin_output = _resolve_kotlin_output()

        await asyncio.gather(
            generate_swift_from_lexicons_recursive(input_dir, output_dir),
            generate_kotlin_from_lexicons_recursive(input_dir, kotlin_output)
        )


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == '--manifest':
        language = sys.argv[3] if len(sys.argv) > 3 else 'both'
        asyncio.run(run_manifest(sys.argv[2], language))
        sys.exit(0)

    if len(sys.argv) < 3:
        print("Usage: python main.py <input_dir> <output_dir> [language]")
        print("       python main.py --manifest <manifest.json> [language]")
        sys.exit(1)

    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    language = sys.argv[3] if len(sys.argv) > 3 else 'swift'

    asyncio.run(main(input_dir, output_dir, language))
