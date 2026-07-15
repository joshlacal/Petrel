import orjson
import sys
import os
import asyncio
import aiofiles
import re
from collections.abc import Sequence
from swift_code_generator import SwiftCodeGenerator, convert_json_to_swift
from kotlin_code_generator import KotlinCodeGenerator
from kotlin_type_converter import convert_to_pascal_case
from utils import convert_to_camel_case
from cycle_detector import CycleDetector
from generated_projection import write_swift_projection

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

CORE_NAMESPACE_ROOT_PATTERN = re.compile(r'^[a-z][a-z0-9]{0,62}$')
SWIFT_RESERVED_IDENTIFIERS = frozenset({
    'actor', 'any', 'as', 'associatedtype', 'async', 'await', 'break',
    'case', 'catch', 'class', 'consume', 'consuming', 'continue',
    'convenience', 'copy', 'default', 'defer', 'deinit', 'distributed',
    'do', 'dynamic', 'else', 'enum', 'extension', 'fallthrough', 'false',
    'fileprivate', 'final', 'for', 'func', 'get', 'guard', 'if', 'import', 'in',
    'indirect', 'infix', 'init', 'inout', 'internal', 'is', 'isolated',
    'lazy', 'let', 'macro', 'mutating', 'nil', 'nonisolated',
    'nonmutating', 'open', 'operator', 'optional', 'override', 'package',
    'postfix', 'precedencegroup', 'prefix', 'private', 'protocol', 'public',
    'repeat', 'required', 'rethrows', 'return', 'self', 'some', 'static',
    'struct', 'subscript', 'super', 'switch', 'throw', 'throws', 'true',
    'try', 'typealias', 'unowned', 'var', 'weak', 'where', 'while', 'yield',
})
RESERVED_CORE_NAMESPACE_PROPERTIES = frozenset({'logout', 'storage'})
RESERVED_CORE_NAMESPACE_TYPES = frozenset({'NetworkService', 'Sendable', 'Type'})

def normalize_core_namespace_roots(
    value: Sequence[str],
    source: str = 'core_namespace_roots',
) -> tuple[str, ...]:
    """Validate, deduplicate, and deterministically order core-owned roots."""
    if isinstance(value, (str, bytes, bytearray)) or not isinstance(value, Sequence):
        raise ValueError(f"{source} must be a sequence of non-empty strings")

    roots = []
    root_set = set()
    property_owners = {}
    type_owners = {}
    for index, root in enumerate(value):
        if not isinstance(root, str) or not root.strip():
            raise ValueError(
                f"{source}[{index}] must be a non-empty namespace-root string"
            )
        if root != root.strip():
            raise ValueError(
                f"{source}[{index}] must not contain leading or trailing whitespace"
            )
        if not CORE_NAMESPACE_ROOT_PATTERN.fullmatch(root):
            raise ValueError(
                f"{source}[{index}] must be one canonical lowercase, "
                "Swift-safe namespace-root segment"
            )
        if root in SWIFT_RESERVED_IDENTIFIERS:
            raise ValueError(f"{source}[{index}] uses reserved Swift identifier '{root}'")
        if root in root_set:
            continue

        property_name = lower_camel(root)
        type_name = convert_to_camel_case(root)
        if property_name in RESERVED_CORE_NAMESPACE_PROPERTIES:
            raise ValueError(
                f"{source}[{index}] collides with ATProtoClient member '{property_name}'"
            )
        if type_name in RESERVED_CORE_NAMESPACE_TYPES:
            raise ValueError(
                f"{source}[{index}] collides with generated type '{type_name}'"
            )

        property_owner = property_owners.get(property_name)
        type_owner = type_owners.get(type_name)
        if property_owner is not None or type_owner is not None:
            collision = property_owner or type_owner
            raise ValueError(
                f"{source}[{index}] collides with namespace root '{collision}'"
            )

        root_set.add(root)
        roots.append(root)
        property_owners[property_name] = root
        type_owners[type_name] = root
    return tuple(sorted(roots))

def load_manifest(path):
    """Load a generation manifest (JSON). Paths inside are relative to CWD."""
    with open(path, 'rb') as f:
        return orjson.loads(f.read())

def is_excluded(lexicon_id, exclude_namespaces):
    return any(
        lexicon_id == ns or lexicon_id.startswith(ns + '.')
        for ns in exclude_namespaces
    )

async def load_lexicons(dirs, exclude_namespaces, cycle_detector, skip_ids=()):
    """Load lexicon JSONs from `dirs`, registering all types with `cycle_detector`.

    Returns [(filepath, lexicon)]. `skip_ids` skips lexicons by id — used so an
    overlay's emit set shadows identically-named lexicons in the reference set
    (avoids double type registration). Both emit and reference sets register
    types for cross-package type resolution.
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
                if lexicon_id in skip_ids:
                    continue

                # Register types with cycle detector
                defs = lexicon.get('defs', {})
                for def_name, def_schema in defs.items():
                    cycle_detector.add_type(lexicon_id, def_name, def_schema)

                # Also register query/procedure output unions
                main_def = defs.get('main', {})
                if main_def.get('type') in ['query', 'procedure']:
                    output = main_def.get('output')
                    output_schema = output.get('schema') if isinstance(output, dict) else None
                    if isinstance(output_schema, dict) and output_schema.get('type') == 'object':
                        cycle_detector.add_output_type(lexicon_id, output_schema)

                loaded.append((filepath, lexicon))
    return loaded

def build_namespace_hierarchy(lexicon_ids):
    """Builds the 3-level namespace tree used for client namespace classes."""
    hierarchy = {}
    for lexicon_id in lexicon_ids:
        current = hierarchy
        for part in lexicon_id.split('.')[:3]:
            current = current.setdefault(part, {})
    return hierarchy

async def generate_swift_from_lexicons_recursive(
    folder_path,
    output_folder: str,
    exclude_namespaces=DEFAULT_EXCLUDED_NAMESPACES,
    reference_dirs=(),
    overlay=False,
    package_name='Petrel',
    core_namespace_roots: Sequence[str] = (),
):
    type_dict = {}
    namespace_hierarchy = {}
    expected_files = {}
    cycle_detector = CycleDetector()
    core_namespace_roots = normalize_core_namespace_roots(core_namespace_roots)

    for root in core_namespace_roots:
        namespace_hierarchy[root] = {}

    emit_dirs = folder_path if isinstance(folder_path, (list, tuple)) else [folder_path]

    # First pass: load the emit set, then the reference set (type resolution only).
    # The emit set shadows the reference set: a lexicon present in both (e.g. while
    # custom lexicons still live in the core tree during migration) is treated as
    # overlay-owned and excluded from the reference hierarchy.
    lexicons = await load_lexicons(emit_dirs, exclude_namespaces, cycle_detector)
    emit_ids = {lex.get('id', '') for _, lex in lexicons}
    reference_lexicons = await load_lexicons(
        reference_dirs, exclude_namespaces, cycle_detector, skip_ids=emit_ids
    )
    reference_hierarchy = build_namespace_hierarchy(
        lex.get('id', '') for _, lex in reference_lexicons
    )

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

    def add_expected_file(relative_path, content):
        if relative_path in expected_files:
            raise ValueError(f"duplicate generated Swift target: {relative_path}")
        expected_files[relative_path] = content

    def process_lexicon(filepath, lexicon):
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

        if overlay:
            # Overlay files compile in a separate module and need the core import.
            swift_code = swift_code.replace('import Foundation', 'import Foundation\nimport Petrel', 1)

        # Create hierarchical output path based on lexicon namespace
        # e.g., "app.bsky.feed.post" -> "Lexicons/App/Bsky/"
        namespace_path = get_namespace_path(lexicon_id)
        output_filename = f"{convert_to_camel_case(lexicon_id)}.swift"
        output_file_path = f"Lexicons/{namespace_path}/{output_filename}"
        add_expected_file(output_file_path, swift_code)

    # Second pass: Generate code with cycle information
    for filepath, lexicon in lexicons:
        process_lexicon(filepath, lexicon)

    if overlay:
        # Overlay: extend the core client's namespace tree instead of regenerating it,
        # and register this package's types with the core decoder registry.
        overlay_namespaces = generate_swift_overlay_namespaces(
            namespace_hierarchy,
            reference_hierarchy,
            core_namespace_roots=core_namespace_roots,
        )
        overlay_client = (
            "import Foundation\nimport Petrel\n\n"
            f"// Generated namespace extensions for the {package_name} overlay package.\n\n"
            + overlay_namespaces
        )
        overlay_client_path = f'Client/ATProtoClient+{package_name}.swift'
        add_expected_file(overlay_client_path, overlay_client)

        registration_code = generate_overlay_registration(type_dict, package_name)
        registration_path = f'Client/{package_name}Lexicons.swift'
        add_expected_file(registration_path, registration_code)
    else:
        type_factory_code = generate_ATProtocolValueContainer_enum(type_dict)
        swift_namespace_classes = generate_swift_namespace_classes(namespace_hierarchy)
        atproto_client = render_atproto_client(swift_namespace_classes)

        # Output ATProtocolValueContainer to Core/Types within output folder
        type_factory_file_path = 'Core/Types/ATProtocolValueContainer.swift'
        add_expected_file(type_factory_file_path, type_factory_code)

        # Output main client file to Client directory within output folder
        class_factory_file_path = 'Client/ATProtoClient+Generated.swift'
        add_expected_file(class_factory_file_path, atproto_client)

    await write_swift_projection(output_folder, expected_files)

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

def generate_swift_overlay_namespaces(
    emit_hierarchy,
    reference_hierarchy,
    core_namespace_roots: Sequence[str] = (),
):
    """Namespace tree for an overlay package, as extensions on the core client.

    Nodes that already exist in the core (reference) hierarchy are extended;
    new nodes become nested values declared inside an extension, so e.g.
    ATProtoClient.Blue.Catbird.MlsChat resolves exactly like a core namespace
    and the per-lexicon method extensions attach unchanged.
    """
    sections = []
    owned_reference_hierarchy = dict(reference_hierarchy)
    for root in normalize_core_namespace_roots(core_namespace_roots):
        owned_reference_hierarchy.setdefault(root, {})

    def class_path(parts):
        return 'ATProtoClient' + ''.join('.' + convert_to_camel_case(p) for p in parts)

    def render_new_value_tree(name, sub, depth):
        indent = '    ' * depth
        class_name = convert_to_camel_case(name)
        code = f"{indent}public struct {class_name}: Sendable {{\n"
        code += f"{indent}    public let networkService: NetworkService\n"
        code += f"{indent}    public init(networkService: NetworkService) {{\n"
        code += f"{indent}        self.networkService = networkService\n"
        code += f"{indent}    }}\n\n"
        for child_name, child_sub in sub.items():
            child_class = convert_to_camel_case(child_name)
            code += (
                f"{indent}    public var {lower_camel(child_name)}: {child_class} "
                f"{{ {child_class}(networkService: networkService) }}\n\n"
            )
            code += render_new_value_tree(child_name, child_sub, depth + 1)
        code += f"{indent}}}\n\n"
        return code

    def render_extension(parent_parts, name, sub):
        target = class_path(parent_parts)
        class_name = convert_to_camel_case(name)
        prop = lower_camel(name)
        code = f"public extension {target} {{\n"
        # Computed access preserves immutable value semantics. On the actor this is
        # actor-isolated, matching the core root accessor (`await client.blue`).
        code += f"    var {prop}: {class_name} {{ {class_name}(networkService: networkService) }}\n\n"
        code += render_new_value_tree(name, sub, 1)
        code += "}\n\n"
        return code

    def walk(emit_node, ref_node, parts):
        for name, sub in emit_node.items():
            if ref_node is not None and name in ref_node:
                walk(sub, ref_node[name], parts + [name])
            else:
                sections.append(render_extension(parts, name, sub))

    walk(emit_hierarchy, owned_reference_hierarchy, [])
    return ''.join(sections)


def generate_overlay_registration(type_dict, package_name):
    """Startup registration of overlay types with the core decoder registry."""
    lines = [
        'import Foundation',
        'import Petrel',
        '',
        f'/// Registers all {package_name} lexicon types with Petrel\'s ATProtocolValueContainer',
        '/// decoder registry so they decode as .knownType when embedded in core responses.',
        '/// Call once at app startup, before decoding any responses containing these types.',
        f'public enum {package_name}Lexicons {{',
        '    public static func register() {',
    ]
    for type_key, swift_type in type_dict.items():
        lines.append(
            f'        ATProtocolValueContainer.registerDecoder(forType: "{type_key}", as: {swift_type}.self)'
        )
    lines += [
        '    }',
        '}',
        '',
    ]
    return '\n'.join(lines)


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
            swift_code += (
                f"public var {prop_name}: {namespace_class} "
                f"{{ {namespace_class}(networkService: networkService) }}\n\n"
            )
            if prop_name != namespace.lower():
                swift_code += f"@available(*, deprecated, renamed: \"{prop_name}\")\n"
                swift_code += f"public var {namespace.lower()}: {namespace_class} {{ {prop_name} }}\n\n"
            swift_code += f"public struct {namespace_class}: Sendable {{\n"
            swift_code += f"    public let networkService: NetworkService\n"
            swift_code += f"    public init(networkService: NetworkService) {{\n"
            swift_code += f"        self.networkService = networkService\n    }}\n\n"
            swift_code += generate_swift_namespace_classes(sub_hierarchy, network_manager, depth + 1)
            swift_code += "}\n\n"
    else:
        for namespace, sub_namespaces in namespace_hierarchy.items():
            class_name = convert_to_camel_case(namespace)
            prop_name = lower_camel(namespace)
            swift_code += (
                f"{indent}public var {prop_name}: {class_name} "
                f"{{ {class_name}(networkService: networkService) }}\n\n"
            )
            if prop_name != namespace.lower():
                swift_code += f"{indent}@available(*, deprecated, renamed: \"{prop_name}\")\n"
                swift_code += f"{indent}public var {namespace.lower()}: {class_name} {{ {prop_name} }}\n\n"
            swift_code += f"{indent}public struct {class_name}: Sendable {{\n"
            swift_code += f"{indent}    public let networkService: NetworkService\n"
            swift_code += f"{indent}    public init(networkService: NetworkService) {{\n"
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
    overlay=False,
    package_name='Petrel',
):
    """Generate Kotlin code from lexicons."""
    namespace_hierarchy = {}
    cycle_detector = CycleDetector()

    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    print("Generating Kotlin code...")

    emit_dirs = folder_path if isinstance(folder_path, (list, tuple)) else [folder_path]

    # First pass: load the emit set, then the reference set (type resolution only).
    # Emit shadows reference (see Swift counterpart).
    lexicons = await load_lexicons(emit_dirs, exclude_namespaces, cycle_detector)
    emit_ids = {lex.get('id', '') for _, lex in lexicons}
    reference_lexicons = await load_lexicons(
        reference_dirs, exclude_namespaces, cycle_detector, skip_ids=emit_ids
    )
    reference_hierarchy = build_namespace_hierarchy(
        lex.get('id', '') for _, lex in reference_lexicons
    )

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
        kotlin_code = KotlinCodeGenerator(lexicon, cycle_detector, overlay=overlay).convert()

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
    client_dir = os.path.join(output_folder, 'client')
    os.makedirs(client_dir, exist_ok=True)

    if overlay:
        overlay_namespaces = generate_kotlin_overlay_namespaces(namespace_hierarchy, reference_hierarchy)
        overlay_path = os.path.join(client_dir, f'{package_name}Namespaces.kt')
        async with aiofiles.open(overlay_path, 'w') as f:
            await f.write(overlay_namespaces)
    else:
        kotlin_namespace_classes = generate_kotlin_namespace_classes(namespace_hierarchy)
        kotlin_client = render_kotlin_atproto_client(kotlin_namespace_classes)

        # Output main client file to client directory within output folder
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


def generate_kotlin_overlay_namespaces(emit_hierarchy, reference_hierarchy):
    """Namespace tree for a Kotlin overlay module.

    Kotlin cannot add nested classes to another module's type, so new namespace
    nodes become standalone classes (BlueCatbirdMlsChatNamespace) reached via
    extension vals on the core client (or on an existing core inner class)."""
    extensions = []
    classes = []

    def pascal_concat(parts):
        return ''.join(convert_to_pascal_case(p) for p in parts)

    def declare_tree(parts, name, sub):
        cls = pascal_concat(parts + [name]) + 'Namespace'
        lines = [f"class {cls}(val client: ATProtoClient) {{"]
        for child, child_sub in sub.items():
            child_cls = pascal_concat(parts + [name, child]) + 'Namespace'
            lines.append(f"    val {lower_camel(child)}: {child_cls} get() = {child_cls}(client)")
        lines.append("}")
        classes.append('\n'.join(lines))
        for child, child_sub in sub.items():
            declare_tree(parts + [name], child, child_sub)

    def emit_new(parent_parts, name, sub):
        cls = pascal_concat(parent_parts + [name]) + 'Namespace'
        prop = lower_camel(name)
        if not parent_parts:
            extensions.append(f"val ATProtoClient.{prop}: {cls} get() = {cls}(this)")
        else:
            parent_target = 'ATProtoClient.' + '.'.join(convert_to_pascal_case(p) for p in parent_parts)
            extensions.append(f"val {parent_target}.{prop}: {cls} get() = {cls}(client)")
        declare_tree(parent_parts, name, sub)

    def walk(emit_node, ref_node, parts):
        for name, sub in emit_node.items():
            if ref_node is not None and name in ref_node:
                walk(sub, ref_node[name], parts + [name])
            else:
                emit_new(parts, name, sub)

    walk(emit_hierarchy, reference_hierarchy, [])

    header = (
        "// Generated namespace extensions for an overlay package.\n\n"
        "package blue.catbird.petrel.generated\n\n"
        "import blue.catbird.petrel.client.*\n\n"
    )
    return header + '\n'.join(extensions) + '\n\n' + '\n\n'.join(classes) + '\n'


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
    package = manifest.get('package', {})
    kind = package.get('kind', 'core')
    package_name = package.get('name', 'Petrel')
    core_namespace_roots = normalize_core_namespace_roots(
        package.get('core_namespace_roots', ()),
        source='package.core_namespace_roots',
    )
    if kind not in ('core', 'overlay'):
        raise ValueError(f"Unknown package.kind '{kind}' in {manifest_path}")
    overlay = kind == 'overlay'
    if overlay and not reference_dirs:
        raise ValueError(f"overlay manifest {manifest_path} must declare lexicons.reference dirs")

    tasks = []
    swift_cfg = manifest.get('swift')
    if swift_cfg and language in ('swift', 'both'):
        tasks.append(generate_swift_from_lexicons_recursive(
            emit_dirs, swift_cfg['output'],
            exclude_namespaces=exclude, reference_dirs=reference_dirs,
            overlay=overlay, package_name=package_name,
            core_namespace_roots=core_namespace_roots,
        ))
    kotlin_cfg = manifest.get('kotlin')
    if kotlin_cfg and language in ('kotlin', 'both'):
        tasks.append(generate_kotlin_from_lexicons_recursive(
            emit_dirs, kotlin_cfg['output'],
            exclude_namespaces=exclude, reference_dirs=reference_dirs,
            overlay=overlay, package_name=package_name,
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
