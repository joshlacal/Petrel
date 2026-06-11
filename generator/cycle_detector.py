"""
Detects circular type dependencies in lexicon definitions.
Used to identify which properties need indirect boxing to break cycles.
"""

from typing import Dict, Set, List, Tuple, Optional
from utils import convert_to_camel_case, convert_ref


class CycleDetector:
    def __init__(self):
        # Maps Swift type name to its properties and their types
        # Format: {"TypeName": {"propName": "PropType"}}
        self.type_properties: Dict[str, Dict[str, str]] = {}
        # Maps lexicon ref to Swift type name
        self.ref_to_type: Dict[str, str] = {}
        # Properties that need boxing (Swift type name, property name)
        self.circular_properties: Set[Tuple[str, str]] = set()
        # Enums that need to be indirect
        self.indirect_enums: Set[str] = set()
        # Maps union name to its variants (Swift type names)
        self.union_variants: Dict[str, Set[str]] = {}

    def add_type(self, lexicon_id: str, def_name: str, def_schema: Dict):
        """Register a type and its properties"""
        schema_type = def_schema.get('type')

        if schema_type not in ['object', 'record', 'array']:
            return

        # Handle union arrays (which become enums)
        if schema_type == 'array' and def_schema.get('items', {}).get('type') == 'union':
            refs = def_schema['items'].get('refs', [])
            swift_base = convert_to_camel_case(lexicon_id)
            union_name = f"{swift_base}.{convert_to_camel_case(def_name)}"

            variants = set()
            for ref in refs:
                if ref.startswith('#'):
                    full_ref = f"{lexicon_id}{ref}"
                else:
                    full_ref = ref
                variants.add(convert_ref(full_ref))

            self.union_variants[union_name] = variants
            return

        if schema_type not in ['object', 'record']:
            return

        # Build Swift type name
        swift_base = convert_to_camel_case(lexicon_id)
        if def_name == 'main':
            swift_type = swift_base
            ref_key = lexicon_id
        else:
            swift_type = f"{swift_base}.{convert_to_camel_case(def_name)}"
            ref_key = f"{lexicon_id}#{def_name}"

        self.ref_to_type[ref_key] = swift_type

        # Extract properties and their types
        properties = def_schema.get('properties', {})
        prop_types = {}

        for prop_name, prop_schema in properties.items():
            prop_type = self._get_property_type(prop_schema, lexicon_id)

            # Handle union properties specially
            if prop_schema.get('type') == 'union':
                # Track the union as a separate type
                union_name = f"{swift_type}{convert_to_camel_case(prop_name)}Union"

                refs = prop_schema.get('refs', [])
                variants = set()
                for ref in refs:
                    if ref.startswith('#'):
                        full_ref = f"{lexicon_id}{ref}"
                    else:
                        full_ref = ref
                    variants.add(convert_ref(full_ref))

                self.union_variants[union_name] = variants

                # Add the union as a property dependency
                prop_types[prop_name] = union_name

            elif prop_schema.get('type') == 'array' and prop_schema.get('items', {}).get('type') == 'union':
                # Handle array of union
                refs = prop_schema['items'].get('refs', [])
                union_name = f"{swift_type}{convert_to_camel_case(prop_name)}Union"

                variants = set()
                for ref in refs:
                    if ref.startswith('#'):
                        full_ref = f"{lexicon_id}{ref}"
                    else:
                        full_ref = ref
                    variants.add(convert_ref(full_ref))

                self.union_variants[union_name] = variants

                # Add the union array as a property dependency
                prop_types[prop_name] = f"[{union_name}]"

            elif prop_type:
                prop_types[prop_name] = prop_type

        self.type_properties[swift_type] = prop_types

    def add_output_type(self, lexicon_id: str, output_schema: Dict):
        """Register query/procedure output unions with 'Output' prefix"""
        swift_base = convert_to_camel_case(lexicon_id)
        properties = output_schema.get('properties', {})

        for prop_name, prop_schema in properties.items():
            # Handle union properties in output
            if prop_schema.get('type') == 'union':
                # Output unions use "Output" as the struct name prefix
                union_name = f"{swift_base}.Output{convert_to_camel_case(prop_name)}Union"

                refs = prop_schema.get('refs', [])
                variants = set()
                for ref in refs:
                    if ref.startswith('#'):
                        full_ref = f"{lexicon_id}{ref}"
                    else:
                        full_ref = ref
                    variants.add(convert_ref(full_ref))

                self.union_variants[union_name] = variants

    def _get_property_type(self, schema: Dict, lexicon_id: str) -> Optional[str]:
        """Extract the Swift type name from a property schema"""
        schema_type = schema.get('type')

        if schema_type == 'ref':
            ref = schema.get('ref', '')
            if not ref:
                return None

            # Handle local refs (start with #)
            if ref.startswith('#'):
                full_ref = f"{lexicon_id}{ref}"
            else:
                full_ref = ref

            # Convert ref to Swift type using our mapping
            swift_type = convert_ref(full_ref)

            # If this is a local ref, it should be prefixed with the lexicon's Swift name
            if ref.startswith('#'):
                swift_base = convert_to_camel_case(lexicon_id)
                def_name = convert_to_camel_case(ref[1:])  # Remove #
                return f"{swift_base}.{def_name}"

            return swift_type
        elif schema_type == 'array':
            items = schema.get('items', {})
            item_type = self._get_property_type(items, lexicon_id)
            return f"[{item_type}]" if item_type else None
        elif schema_type == 'union':
            # Unions are tracked separately and become enums
            # Return None here since the union is tracked via union_variants
            # But we'll handle this in the property tracking
            return None

        return None

    def detect_cycles(self):
        """Detect circular dependencies and mark properties/enums for boxing/indirect"""
        # Build adjacency graph of type dependencies (both structs and enums)
        graph: Dict[str, Set[str]] = {}

        # Add struct dependencies
        for type_name, properties in self.type_properties.items():
            deps = set()
            for prop_type in properties.values():
                # Extract base type (remove array brackets)
                base_type = prop_type.strip('[]')
                if base_type in self.type_properties or base_type in self.union_variants:
                    deps.add(base_type)
            graph[type_name] = deps

        # Add enum dependencies
        for union_name, variants in self.union_variants.items():
            deps = set()
            for variant in variants:
                # Variants can be other structs or enums
                if variant in self.type_properties or variant in self.union_variants:
                    deps.add(variant)
            graph[union_name] = deps

        # Find cycles using DFS
        WHITE = 0  # Unvisited
        GRAY = 1   # Currently in recursion stack
        BLACK = 2  # Completely processed

        colors = {node: WHITE for node in graph}
        all_cycles = []

        def dfs(node: str, path: List[Tuple[str, str]]) -> None:
            """DFS to find cycles. path contains (type, property) tuples"""
            if colors[node] == GRAY:
                # Found a cycle
                # Extract the cycle from the path
                for i, (cycle_node, _) in enumerate(path):
                    if cycle_node == node:
                        cycle = path[i:]
                        all_cycles.append(cycle)
                        return

            if colors[node] == BLACK:
                return

            colors[node] = GRAY

            for neighbor in graph.get(node, set()):
                # Find which property links to this neighbor
                prop_name = self._find_property_to_type(node, neighbor)
                if prop_name:
                    dfs(neighbor, path + [(node, prop_name)])

            colors[node] = BLACK

        # Run DFS from each node
        for node in graph:
            if colors[node] == WHITE:
                dfs(node, [])

        # For each cycle, determine how to break it
        for cycle in all_cycles:
            if len(cycle) < 1:
                continue

            # Check if cycle contains any enums
            enums_in_cycle = [type_name for type_name, _ in cycle if type_name in self.union_variants]

            if enums_in_cycle:
                # If cycle has enums, mark them as indirect (preferred solution)
                for enum_name in enums_in_cycle:
                    self.indirect_enums.add(enum_name)
            else:
                # No enums in cycle, box a struct property instead
                best_prop = None
                best_score = -1

                for type_name, prop_name in cycle:
                    score = 0
                    prop_type = self.type_properties.get(type_name, {}).get(prop_name, '')

                    # Prefer arrays (less commonly accessed in a tight loop)
                    if prop_type.startswith('['):
                        score += 10

                    # Prefer properties further in the cycle
                    score += cycle.index((type_name, prop_name))

                    if score > best_score:
                        best_score = score
                        best_prop = (type_name, prop_name)

                if best_prop:
                    self.circular_properties.add(best_prop)

        # Propagate indirect to enums that contain indirect variants or structs with indirect properties
        # This ensures that if an enum contains a recursive type, it's also marked as indirect
        # even if it's not directly in a cycle
        changed = True
        while changed:
            changed = False
            for union_name, variants in self.union_variants.items():
                if union_name not in self.indirect_enums:
                    # Check if any variant is indirect or contains indirect properties
                    for variant in variants:
                        # Direct indirect enum
                        if variant in self.indirect_enums:
                            self.indirect_enums.add(union_name)
                            changed = True
                            break
                        # Struct with indirect enum properties
                        if variant in self.type_properties:
                            for prop_type in self.type_properties[variant].values():
                                base_type = prop_type.strip('[]')
                                if base_type in self.indirect_enums:
                                    self.indirect_enums.add(union_name)
                                    changed = True
                                    break
                            if changed:
                                break

    def _find_property_to_type(self, source_type: str, target_type: str) -> Optional[str]:
        """Find which property in source_type references target_type"""
        # Check struct properties
        properties = self.type_properties.get(source_type, {})

        for prop_name, prop_type in properties.items():
            # Handle both direct refs and array refs
            base_type = prop_type.strip('[]')
            if base_type == target_type:
                return prop_name

        # Check union variants
        variants = self.union_variants.get(source_type, set())
        if target_type in variants:
            # For unions, return a generic edge label since we mark the whole enum as indirect
            return "variant"

        return None

    def should_box_property(self, swift_type: str, property_name: str) -> bool:
        """Check if a property should be boxed"""
        return (swift_type, property_name) in self.circular_properties

    def should_be_indirect(self, union_name: str) -> bool:
        """Check if a union/enum should be marked as indirect"""
        return union_name in self.indirect_enums
