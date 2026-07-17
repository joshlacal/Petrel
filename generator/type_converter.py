from typing import Dict, Any, List
from utils import convert_to_camel_case, convert_ref as convert_swift_ref

class TypeConverter:
    def __init__(self, swift_code_generator):
        self.swift_code_generator = swift_code_generator

    def convert_ref(self, ref: str) -> str:
        """Resolve a `ref` to a Swift type.

        Per the Lexicon spec, `blob`, `bytes`, and `cid-link` are valid top-level
        definitions and can be `ref`'d. They have no named Swift type of their
        own, so a ref to such a def must resolve to the built-in primitive type
        (matching inline usage), not a mangled name. All other refs
        (object/record/token/array/string defs) keep their generated named type.

        Handles both the `#frag` shorthand and a fully-qualified self-reference
        (`{current lexicon id}#frag`). External refs to primitive defs would need
        the reference-lexicon corpus to resolve and fall through unchanged.
        """
        nsid, _, fragment = ref.partition('#')
        fragment = fragment or 'main'
        if not nsid or nsid == self.swift_code_generator.lexicon_id:
            target = self.swift_code_generator.defs.get(fragment)
            if isinstance(target, dict):
                target_type = target.get('type')
                if target_type == 'string' and 'enum' in target:
                    return f"Defs{convert_to_camel_case(fragment)}"
                if target_type == 'blob':
                    return 'Blob'
                if target_type == 'bytes':
                    return 'Bytes'
                if target_type == 'cid-link':
                    return 'CID'
        return convert_swift_ref(ref)

    def determine_swift_type(self, name: str, prop: Dict[str, Any], required_fields: List[str], current_struct_name: str, isOptional: bool = None, context_identity=None) -> str:
        swift_type = ""
        prop_type = prop.get('type')
        string_format = prop.get('format')
        is_optional = "?" if isOptional or name not in required_fields else ""

        if prop_type == 'string':
            if 'enum' in prop:
                swift_type = f"{convert_to_camel_case(current_struct_name)}{convert_to_camel_case(name)}"
                identity = (
                    "inline",
                    self.swift_code_generator.lexicon_id,
                    context_identity if context_identity is not None else ("rendered", current_struct_name),
                    name,
                )
                self.swift_code_generator.enum_generator.generate_closed_string_enum(
                    swift_type, prop['enum'], identity
                )
            elif string_format == 'datetime':
                swift_type = "ATProtocolDate"
            elif string_format == 'uri':
                swift_type = "URI" 
            elif string_format == 'at-uri':
                swift_type = "ATProtocolURI" 
            elif string_format == 'at-identifier':
                swift_type = "ATIdentifier"
            elif string_format == 'cid':
                swift_type = "CID"
            elif string_format == 'did':
                swift_type = "DID"
            elif string_format == 'handle':
                swift_type = "Handle"
            elif string_format == 'nsid':
                swift_type = "NSID"
            elif string_format == 'tid':
                swift_type = "TID"
            elif string_format == 'record-key':
                swift_type = "RecordKey"
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
        elif prop_type == 'cid-link':
            swift_type = "CID"
        elif prop_type == 'bytes':
            swift_type = "Bytes"
        elif prop_type == 'blob':
            swift_type = "Blob"
        elif prop_type == 'object':
            swift_type = "[String: ATProtocolValueContainer]" 
        elif prop_type == 'unknown':
            if name == 'didDoc':
                swift_type = "DIDDocument"
            else:
                swift_type = "ATProtocolValueContainer"
        elif prop_type == 'union':
            union_name = f"{convert_to_camel_case(current_struct_name)}{convert_to_camel_case(name)}Union"
            refs = prop.get('refs', [])
            self.swift_code_generator.enum_generator.generate_enum_for_union(current_struct_name, name, refs)
            return union_name
        elif prop_type == 'array':
            items = prop['items']
            if items.get('type') == 'union':
                union_name = f"{convert_to_camel_case(current_struct_name)}{convert_to_camel_case(name)}Union"
                refs = items['refs']
                self.swift_code_generator.enum_generator.generate_enum_for_union(current_struct_name, name, refs)
                item_type = union_name
            else:
                item_type = self.determine_swift_type(
                    name, items, required_fields, current_struct_name,
                    isOptional=False, context_identity=context_identity,
                )
            swift_type = f"[{item_type}]"
        else:
            swift_type = prop_type.capitalize()

        return swift_type
