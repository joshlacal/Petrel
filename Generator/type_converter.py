from typing import Dict, Any, List
from utils import convert_to_camel_case, convert_ref

class TypeConverter:
    def __init__(self, swift_code_generator):
        self.swift_code_generator = swift_code_generator

    def determine_swift_type(self, name: str, prop: Dict[str, Any], required_fields: List[str], current_struct_name: str, isOptional: bool = None) -> str:
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
            swift_type = convert_ref(prop['ref']) 
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
                item_type = self.determine_swift_type(name, items, required_fields, current_struct_name, isOptional=False)
            swift_type = f"[{item_type}]"
        else:
            swift_type = prop_type.capitalize()

        return swift_type
