from typing import Any, Dict, List, Optional
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
        nsid, separator, fragment = ref.partition('#')
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

        registry = getattr(self.swift_code_generator.cycle_detector, 'schemas_by_ref', None)
        if registry is not None:
            qualified_ref = ref if separator else f"{ref}#main"
            target = registry.get(qualified_ref)
            if isinstance(target, dict):
                target_type = target.get('type')
                if target_type == 'string' and 'enum' in target:
                    pre_hash_parts = nsid.split('.')
                    camel_case_pre_hash = ''.join([convert_to_camel_case(part) for part in pre_hash_parts])
                    return f"{camel_case_pre_hash}.Defs{convert_to_camel_case(fragment)}"
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
            elif string_format == 'space-ref':
                # Not a narrower at-uri: the public AT-URI grammar admits at most
                # two path segments, so at://{did}/space/{type}/{skey} does not
                # parse as one. ATProtocolURI would report "space" as the
                # collection and silently drop the skey.
                swift_type = "SpaceRef"
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


# ---------------------------------------------------------------------------
# App Intents support
#
# The two tables below encode a single fact each time: which Petrel *wrapper*
# Swift type a given lexicon string `format` produces (mirrors the format
# switch in `TypeConverter.determine_swift_type` above), and how to construct/
# unwrap that wrapper type from/to a plain Swift value an App Intents
# `@Parameter`/`AppEntity` property can hold directly (String/Date/URL/Int/
# Bool/Double). This is intentionally duplicated rather than routed through
# `TypeConverter.determine_swift_type` itself: that method is bound to a
# stateful `SwiftCodeGenerator` instance (it side-effects union/enum
# generation for 'union'/'array' props), whereas `intent_facing_type` and
# `intent_entity_extraction` below need to be pure functions callable during
# manifest curation, before any SwiftCodeGenerator/CycleDetector exists.
#
# The constructor/accessor expressions were verified against the checked-in
# runtime types, not guessed:
#   Sources/Petrel/Core/Utils/ATProtoTypes.swift
#     DID(didString:) throws            .didString() -> String
#     Handle(handleString:) throws      .value -> String
#     ATIdentifier(string:) throws      .stringValue() -> String
#     ATProtocolURI(uriString:) throws  .uriString() -> String
#     NSID(nsidString:) throws          .nsidString() -> String
#     RecordKey(keyString:) throws      .value -> String
#     TID(tidString:) throws            .toString() -> String
#     URI(url:) NON-throwing            .url -> URL? (always Optional, even
#                                        for a non-Optional source URI)
#   Sources/Petrel/Core/Types/CID.swift
#     CID(cidString:) throws            .string -> String
#   Sources/Petrel/Core/Utils/Languages.swift
#     LanguageCodeContainer(languageCode:) NON-throwing
#   Sources/Petrel/Core/Utils/DateValidation.swift
#     ATProtocolDate(date:) NON-throwing .date -> Date
# ---------------------------------------------------------------------------

class CurationError(ValueError):
    """Raised when a lexicon property cannot be curated into App Intents source.

    Callers (generator/app_intents_generator.py) catch this to add manifest/
    intent/parameter context before re-raising, so the top-level error message
    always points at the offending manifest entry.
    """


# lexicon string `format` -> Petrel wrapper Swift type name (only formats that
# `intent_facing_type`/`intent_entity_extraction` know how to bridge; 'language'
# is deliberately excluded from entity property extraction — see
# `intent_entity_extraction` below).
_INTENT_WRAPPER_BY_FORMAT = {
    'did': 'DID',
    'handle': 'Handle',
    'at-identifier': 'ATIdentifier',
    'at-uri': 'ATProtocolURI',
    'cid': 'CID',
    'nsid': 'NSID',
    'tid': 'TID',
    'record-key': 'RecordKey',
    'language': 'LanguageCodeContainer',
}

# Petrel wrapper Swift type -> (intent-facing Swift type, constructor expression
# template with `{v}` as the substitution point, whether the constructor throws).
# Used by `intent_facing_type` to go String -> wrapper (build a Petrel Parameters/
# Input field from an App Intents parameter value).
_INTENT_PARAM_BRIDGE = {
    'DID': ('String', 'try DID(didString: {v})', True),
    'Handle': ('String', 'try Handle(handleString: {v})', True),
    'ATIdentifier': ('String', 'try ATIdentifier(string: {v})', True),
    'ATProtocolURI': ('String', 'try ATProtocolURI(uriString: {v})', True),
    'CID': ('String', 'try CID(cidString: {v})', True),
    'NSID': ('String', 'try NSID(nsidString: {v})', True),
    'TID': ('String', 'try TID(tidString: {v})', True),
    'RecordKey': ('String', 'try RecordKey(keyString: {v})', True),
    'LanguageCodeContainer': ('String', 'LanguageCodeContainer(languageCode: {v})', False),
}

# Petrel wrapper Swift type -> (intent-facing Swift type, direct-access
# extraction template, optional-chained extraction template). Used by
# `intent_entity_extraction` to go wrapper -> String/Date/URL (project a
# Petrel view's field onto an AppEntity's stored property). `URI` always maps
# to the optional-chained form regardless of source optionality because
# `.url` is itself a computed `URL?` (can be nil even for a non-nil `URI`).
_INTENT_ENTITY_EXTRACT = {
    'String': ('String', '{v}', '{v}'),
    'DID': ('String', '{v}.didString()', '{v}?.didString()'),
    'Handle': ('String', '{v}.value', '{v}?.value'),
    'ATIdentifier': ('String', '{v}.stringValue()', '{v}?.stringValue()'),
    'NSID': ('String', '{v}.nsidString()', '{v}?.nsidString()'),
    'CID': ('String', '{v}.string', '{v}?.string'),
    'ATProtocolURI': ('String', '{v}.uriString()', '{v}?.uriString()'),
    'RecordKey': ('String', '{v}.value', '{v}?.value'),
    'TID': ('String', '{v}.toString()', '{v}?.toString()'),
    'ATProtocolDate': ('Date', '{v}.date', '{v}?.date'),
    'URI': ('URL', '{v}.url', '{v}?.url'),
}


def intent_facing_type(prop: Dict[str, Any], enum_type_name: Optional[str] = None) -> Dict[str, Any]:
    """Map a lexicon parameter/input property schema to its App-Intent-facing
    Swift representation.

    Mapping (see generator/app_intents_generator.py for the manifest-level
    curation that calls this): string formats did/handle/at-identifier/
    at-uri/cid/nsid/tid/record-key/language -> String; datetime -> Date;
    uri -> URL; plain/unrecognized-format string -> String; integer -> Int;
    boolean -> Bool; number -> Double; a string with `knownValues` -> the
    caller-supplied generated AppEnum name.

    Returns a dict:
      swift_type: the App-Intent-facing Swift type (String/Date/URL/Int/Bool/
        Double, or `enum_type_name` for knownValues).
      bridge_expr_template: expression that builds the Petrel wrapper-typed
        value from the intent-facing value; `{v}` is the substitution point
        (a non-Optional Swift expression).
      needs_throws: whether `bridge_expr_template` contains a throwing call
        (informational — the template already includes the `try` keyword
        itself; callers building an outer `.map {}` closure need this to know
        whether the closure — and therefore its enclosing `try`-covered
        expression — throws).
      is_enum: True for the knownValues case.

    Raises CurationError for property shapes this generator does not support
    as App Intents parameters: unions, refs (including refs to composite
    objects), arrays, plain objects, `unknown`, `bytes`, `blob`, and
    `cid-link`. Arrays and refs are deliberately out of scope for parameter
    curation in this version — a manifest author who needs one must curate it
    explicitly via a `parameterOverrides` entry (resolve it as an AppEntity
    parameter instead of a primitive) rather than relying on generic bridging.
    """
    prop_type = prop.get('type')

    if prop_type == 'string' and prop.get('knownValues'):
        if not enum_type_name:
            raise CurationError(
                "a knownValues string property requires an AppEnum type name "
                "(internal error: caller did not supply enum_type_name)"
            )
        return {
            'swift_type': enum_type_name,
            'bridge_expr_template': '{v}.rawValue',
            'needs_throws': False,
            'is_enum': True,
        }

    if prop_type == 'string':
        fmt = prop.get('format')
        if fmt == 'datetime':
            return {
                'swift_type': 'Date',
                'bridge_expr_template': 'ATProtocolDate(date: {v})',
                'needs_throws': False,
                'is_enum': False,
            }
        if fmt == 'uri':
            return {
                'swift_type': 'URL',
                'bridge_expr_template': 'URI(url: {v})',
                'needs_throws': False,
                'is_enum': False,
            }
        if fmt in _INTENT_WRAPPER_BY_FORMAT:
            wrapper = _INTENT_WRAPPER_BY_FORMAT[fmt]
            swift_type, template, needs_throws = _INTENT_PARAM_BRIDGE[wrapper]
            return {
                'swift_type': swift_type,
                'bridge_expr_template': template,
                'needs_throws': needs_throws,
                'is_enum': False,
            }
        # Plain string, or a format this table doesn't recognize — matches
        # determine_swift_type's own fallback to "String" above.
        return {'swift_type': 'String', 'bridge_expr_template': '{v}', 'needs_throws': False, 'is_enum': False}

    if prop_type == 'integer':
        return {'swift_type': 'Int', 'bridge_expr_template': '{v}', 'needs_throws': False, 'is_enum': False}
    if prop_type == 'boolean':
        return {'swift_type': 'Bool', 'bridge_expr_template': '{v}', 'needs_throws': False, 'is_enum': False}
    if prop_type == 'number':
        return {'swift_type': 'Double', 'bridge_expr_template': '{v}', 'needs_throws': False, 'is_enum': False}

    raise CurationError(
        f"lexicon property type '{prop_type}' cannot be exposed as an App Intents parameter "
        "(unions, refs, arrays, objects, 'unknown', 'bytes', 'blob', and 'cid-link' all need "
        "explicit curation via a parameterOverrides entry, or must be excluded)"
    )


def intent_entity_extraction(prop: Dict[str, Any]) -> Optional[Dict[str, str]]:
    """Resolve a view-def property schema to the info needed to project it onto
    an AppEntity stored property.

    Returns a dict (swift_type, direct_template, optional_chain_template) or
    None when the property type is not supported for entity projection —
    boolean/number, refs, unions, arrays, objects, 'unknown', 'bytes',
    'blob', 'cid-link', and the 'language' string format (BCP-47 language tags
    have no natural String/Date/URL projection worth guessing at; a manifest
    author who needs one should exclude it). Integers project as Int.
    Callers must turn None into a CurationError that names the offending
    property for context.
    """
    if prop.get('type') == 'integer':
        return {
            'swift_type': 'Int',
            'direct_template': '{v}',
            'optional_chain_template': '{v}',
        }
    if prop.get('type') != 'string':
        return None

    fmt = prop.get('format')
    if fmt is None:
        wrapper = 'String'
    elif fmt == 'datetime':
        wrapper = 'ATProtocolDate'
    elif fmt == 'uri':
        wrapper = 'URI'
    elif fmt in _INTENT_WRAPPER_BY_FORMAT and _INTENT_WRAPPER_BY_FORMAT[fmt] != 'LanguageCodeContainer':
        wrapper = _INTENT_WRAPPER_BY_FORMAT[fmt]
    else:
        return None

    swift_type, direct_template, optional_chain_template = _INTENT_ENTITY_EXTRACT[wrapper]
    return {
        'swift_type': swift_type,
        'direct_template': direct_template,
        'optional_chain_template': optional_chain_template,
    }
