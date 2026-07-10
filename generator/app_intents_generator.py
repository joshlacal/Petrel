"""App Intents emit mode for the lexicon code generator.

Reads a manifest with `package.kind == "app-intents"` and emits Swift
`AppIntent` / `AppEntity` / `AppEnum` source directly from a curated slice of
the referenced lexicons. This does NOT reuse `SwiftCodeGenerator` — an App
Intent's parameters and an AppEntity's stored properties are a small,
hand-curated projection of a query/procedure/def's shape (exclusions,
entity-resolved parameters, single-vs-collection results), not a 1:1 mirror
of it, so a bespoke generator driven by explicit manifest curation is a
better fit than threading a new emit mode through the existing per-lexicon
pipeline.

Manifest schema (package.kind == "app-intents"):

    {
      "package": {"kind": "app-intents", "name": "<display>"},
      "lexicons": {"reference": ["<dirs relative to this manifest file>"]},
      "swift": {"output": "<dir relative to this manifest file>"},
      "appIntents": {
        "availability": "iOS 18.0",
        "intents": [
          {
            "id": "<nsid>", "kind": "query"|"procedure"|"recordWrite",
            "structName": "...", "title": "...", "description": "...",
            "parameters": {"<name>": {"title": "...", "requestValue": true}},
            "excludeParameters": ["cursor"],
            "parameterOverrides": {"<name>": {"resolveAs": "<EntityName>", "bridge": "<entity field>"}},
            "confirmation": false,
            "returns": {"entity": "<EntityName>", "outputPath": "<output field, or omitted/'.' for the whole output>"}
          }
        ],
        "entities": [
          {
            "name": "...", "source": "<nsid>#<def>", "identifier": "<prop>",
            "syncable": true,
            "display": {"title": "<prop>", "titleFallback": "<prop>", "subtitle": "<prop>", "image": "<prop>"},
            "properties": ["..."],
            "query": {
              "kind": "string", "nsid": "...", "param": "q", "resultsPath": "...",
              "byIds": {"nsid": "...", "param": "...", "resultsPath": "..."}
            }
          }
        ]
      }
    }

Design decisions (see also the header comment on `intent_facing_type` in
type_converter.py):

  * Paths under `lexicons.reference` / `swift.output` are resolved relative to
    the manifest FILE's own directory, not the process CWD. This is a
    deliberate departure from the core/overlay manifest convention (paths
    relative to CWD) — app-intents manifests are meant to be authored and run
    from anywhere (including pointing `swift.output` at a scratch directory
    for validation), so anchoring to the manifest file avoids CWD coupling.

  * Query intents must always declare `returns` (an App Intent that fetches
    data and throws it away is not a sensible MVP shape); procedures may omit
    it for a void action.

  * `returns.outputPath` omitted (or `"."`) means "whole output" and requires
    the query's output schema to itself be a `$ref` (a typealias output, e.g.
    `app.bsky.actor.getProfile` aliasing straight to `profileViewDetailed`) —
    this is the "single entity" mode (`ReturnsValue<Entity>`, not an array).
    A named `outputPath` must resolve to a required array-of-$ref (collection
    mode, `ReturnsValue<[Entity]>`) or a required scalar $ref (single mode
    reading one field instead of the whole output).

  * An entity's `source` field names ONE view def, but real endpoints often
    return siblings of that view (e.g. `searchActors` returns
    `profileView` while `getProfile` returns `profileViewDetailed`). Rather
    than requiring the manifest to enumerate every sibling, this generator
    auto-collects every distinct view ref actually used by the entity's own
    `query`/`query.byIds` endpoints AND by any intent whose `returns.entity`
    points at this entity, then emits one `init(from:)` overload per distinct
    ref. This is the "simplest thing that compiles" for reconciling
    `ProfileView` vs `ProfileViewDetailed` in the starter manifest: two
    overloads on one struct, rather than two manifest-level entities or a
    protocol-erased view abstraction.

  * Entity stored properties are restricted to String/Date/URL (scalar,
    non-composite) projections — see `intent_entity_extraction` in
    type_converter.py. A property missing from some (but not all) of an
    entity's resolved source views is treated as optional and synthesized as
    `nil` in the `init(from:)` overloads where it doesn't exist, rather than
    being a hard error, so long as it resolves to the same Swift type
    wherever it IS present.

  * `kind: "recordWrite"` intents perform a com.atproto.repo record
    create/delete with a hydrate-then-write pattern: the intent takes ONE
    entity parameter (the subject), re-fetches its fresh view via
    `recordWrite.subject.hydrate` (supplying the strongRef `cid` and viewer
    state), then creates the record (skipping when `recordWrite.viewerPath`
    already names a record URI) or deletes the record named by that viewer URI
    (skipping when absent). `id` is the RECORD NSID (e.g. app.bsky.feed.like)
    and is intentionally shared by the create/delete pair for one collection;
    `structName` (also the output filename) carries uniqueness. Records are
    synthesized from the lexicon's properties: `subject` + `createdAt` are
    required, anything else must be optional and is emitted as `nil`.

Determinism: this generator is invoked as a fresh `python3` process for each
of the two runs in the byte-stability check, and Python's string hashing is
randomized per-process by default. Every ordered collection that feeds
generated text is therefore either a `list` (JSON array / manifest order,
inherently stable) or a `dict` used purely as an insertion-ordered set/map
(Python dicts preserve insertion order — this is a language guarantee, unlike
`set()`, whose iteration order additionally depends on hash randomization).
No `set()` literal in this module is ever iterated in a way that reaches
generated output; the few that exist are membership-only.
"""

import os
import re

import aiofiles

from cycle_detector import CycleDetector
from main import DEFAULT_EXCLUDED_NAMESPACES, load_lexicons, lower_camel
from templates import TemplateManager
from type_converter import CurationError, intent_entity_extraction, intent_facing_type
from utils import convert_ref, convert_to_camel_case


# ---------------------------------------------------------------------------
# Manifest schema validation
# ---------------------------------------------------------------------------
#
# Allow-lists for every object boundary in the app-intents manifest schema (see
# the module docstring above for the full shape). Without these, an unknown/
# misspelled key (e.g. "requestVlaue" instead of "requestValue") is silently
# ignored by `dict.get(..., default)` instead of erroring — the manifest exits
# 0 but emits the wrong Swift. Every nested object a manifest author can write
# into gets an explicit check.
_TOP_LEVEL_KEYS = {'$comment', 'package', 'lexicons', 'swift', 'appIntents'}
_PACKAGE_KEYS = {'kind', 'name'}
_LEXICONS_KEYS = {'reference', 'exclude_namespaces'}
_SWIFT_KEYS = {'output'}
_APP_INTENTS_KEYS = {'availability', 'intents', 'entities'}
_INTENT_KEYS = {
    'id', 'kind', 'structName', 'title', 'description', 'parameters',
    'excludeParameters', 'parameterOverrides', 'confirmation', 'returns',
    'dialog', 'recordWrite',
}
_ENTITY_KEYS = {'name', 'source', 'identifier', 'syncable', 'indexed', 'display', 'properties', 'customProperties', 'query'}
_CUSTOM_PROPERTY_KEYS = {'name', 'swiftType', 'optional', 'title', 'expr'}
_PARAMETER_META_KEYS = {'title', 'requestValue'}
_PARAMETER_OVERRIDE_KEYS = {'resolveAs', 'bridge'}
_DISPLAY_KEYS = {'title', 'titleFallback', 'subtitle', 'image'}
_QUERY_KEYS = {'kind', 'nsid', 'param', 'resultsPath', 'byIds'}
_QUERY_BY_IDS_KEYS = {'nsid', 'param', 'resultsPath'}
_RETURNS_KEYS = {'entity', 'outputPath', 'scalar'}
_RECORD_WRITE_KEYS = {'action', 'subject', 'viewerPath', 'dialog'}
_RW_SUBJECT_KEYS = {'kind', 'parameter', 'hydrate'}
_RW_PARAM_KEYS = {'name', 'title', 'entity'}
_RW_HYDRATE_KEYS = {'nsid', 'param', 'resultsPath'}
_RW_DIALOG_KEYS = {'success', 'alreadyDone'}

# Lexicon output-field type -> Swift scalar type, for `returns.scalar` (a
# ReturnsValue<Int>/<Bool>/<Double> query, e.g. getUnreadCount's `count`) —
# the counterpart to entity-returning intents for endpoints whose useful
# output is a single primitive rather than a $ref.
_SCALAR_RETURN_TYPES = {'integer': 'Int', 'boolean': 'Bool', 'number': 'Double'}


def _check_known_keys(obj: dict, allowed: set, context: str):
    """Raise CurationError naming every key in `obj` outside `allowed`, plus
    `context` (the manifest path, or the enclosing intent/entity id and the
    object's own path within it) so an unrecognized key errors immediately
    instead of silently no-op'ing via `dict.get(..., default)`."""
    unknown = sorted(set(obj.keys()) - allowed)
    if unknown:
        raise CurationError(
            f"{context}: unknown key(s) {', '.join(unknown)} (allowed: {', '.join(sorted(allowed))})"
        )


# ---------------------------------------------------------------------------
# Path / ref resolution helpers
# ---------------------------------------------------------------------------

def _resolve_path(manifest_dir: str, path: str) -> str:
    return path if os.path.isabs(path) else os.path.normpath(os.path.join(manifest_dir, path))


def normalize_ref(ref: str, current_lexicon_id: str):
    """Split a lexicon `ref` string into (lexicon_id, def_name), resolving a
    local `#foo` ref against `current_lexicon_id`."""
    if ref.startswith('#'):
        return current_lexicon_id, ref[1:]
    if '#' in ref:
        lex_id, def_name = ref.split('#', 1)
        return lex_id, def_name
    return ref, 'main'


def swift_method_name(nsid_last_part: str) -> str:
    """The lowerCamelCase client method name for the last NSID segment —
    mirrors the `lowerCamelCase` Jinja filter's net effect on the PascalCase
    form `SwiftCodeGenerator.generate_query_function`/`..._procedure_function`
    already produce (see generator/templates.py TemplateManager.lowerCamelCase)."""
    pascal = convert_to_camel_case(nsid_last_part)
    return pascal[0].lower() + pascal[1:] if pascal else pascal


def client_path(lexicon_id: str) -> str:
    """The `client.foo.bar.baz(...)` call path for an NSID, matching the
    namespace properties `generate_swift_namespace_classes` emits on
    `ATProtoClient` (lowerCamelCase segments) plus the method name."""
    parts = lexicon_id.split('.')
    namespace = '.'.join(lower_camel(p) for p in parts[:-1])
    return f"{namespace}.{swift_method_name(parts[-1])}"


def _escape_swift_string(s: str) -> str:
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ')


def _display_noun(display_type_name: str) -> str:
    """Human-readable lowercase noun for an entity display type name, for use
    in spoken dialogs: 'Post' -> 'post', 'FeedGenerator' -> 'feed generator'."""
    words = []
    current = ''
    for ch in display_type_name:
        if ch.isupper() and current:
            words.append(current)
            current = ch
        else:
            current += ch
    if current:
        words.append(current)
    return ' '.join(w.lower() for w in words)


def _entity_display_type_name(entity_name: str) -> str:
    return entity_name[:-len('Entity')] if entity_name.endswith('Entity') else entity_name


def _default_property_title(swift_name: str) -> str:
    """authorDisplayName -> 'Author Display Name'."""
    spaced = re.sub(r'(?<!^)(?=[A-Z])', ' ', swift_name)
    return spaced[:1].upper() + spaced[1:]


class LexiconIndex:
    """id -> lexicon lookup plus ref resolution, built once per generator run."""

    def __init__(self, lexicons_by_id: dict):
        self._by_id = lexicons_by_id

    def get(self, lexicon_id: str) -> dict:
        lexicon = self._by_id.get(lexicon_id)
        if lexicon is None:
            raise CurationError(f"lexicon '{lexicon_id}' not found in the manifest's reference set")
        return lexicon

    def resolve_def(self, raw_ref: str, current_lexicon_id: str) -> dict:
        lex_id, def_name = normalize_ref(raw_ref, current_lexicon_id)
        defs = self.get(lex_id).get('defs', {})
        if def_name not in defs:
            raise CurationError(f"def '{def_name}' not found in lexicon '{lex_id}' (from ref '{raw_ref}')")
        return defs[def_name]

    def qualify(self, raw_ref: str, current_lexicon_id: str) -> str:
        lex_id, def_name = normalize_ref(raw_ref, current_lexicon_id)
        return f"{lex_id}#{def_name}"


async def load_reference_index(dirs, exclude_namespaces=DEFAULT_EXCLUDED_NAMESPACES) -> LexiconIndex:
    # `load_lexicons` (generator/main.py) is the same walk core/overlay manifests
    # use; it requires a CycleDetector to register types into, but app-intents
    # curation never needs cycle/indirect-enum analysis, so the detector here is
    # write-only (constructed to satisfy the shared function's API, never read).
    cycle_detector = CycleDetector()
    loaded = await load_lexicons(dirs, exclude_namespaces, cycle_detector)
    by_id = {}
    for _, lexicon in loaded:
        lexicon_id = lexicon.get('id', '')
        if lexicon_id:
            by_id[lexicon_id] = lexicon
    return LexiconIndex(by_id)


def _results_ref(lex_index: LexiconIndex, nsid: str, main_def: dict, results_path: str):
    """Resolve a query's output property to (ref, is_array); requires the
    property to be a required array-of-$ref (the only shape entity query
    results support)."""
    output_obj = main_def.get('output')
    if not output_obj:
        raise CurationError(f"'{nsid}' has no output; cannot use it as an entity query source")
    schema = output_obj.get('schema', {})
    props = schema.get('properties', {})
    if results_path not in props:
        raise CurationError(f"'{nsid}': resultsPath '{results_path}' not found in output properties")
    if results_path not in schema.get('required', []):
        raise CurationError(f"'{nsid}': resultsPath '{results_path}' must be a required output field")
    prop = props[results_path]
    if prop.get('type') != 'array' or prop.get('items', {}).get('type') != 'ref':
        raise CurationError(f"'{nsid}': resultsPath '{results_path}' must be an array of $ref")
    return prop['items']['ref'], True


def resolve_output_element_ref(lex_index: LexiconIndex, nsid: str, main_def: dict, output_path):
    """Resolve `returns.outputPath` (or the whole-output '.'/omitted form) to
    (ref, mode, field). mode is 'collection' (array of $ref) or 'single'
    (whole output ref, or a scalar $ref field). `field` is either a plain
    string (existing single-level outputPath) or, for the one-level
    array-element nesting form ("feed.post"), a dict
    `{'array_field': ..., 'leaf_field': ...}` — see the module docstring's
    "array-element outputPath nesting" note. Callers must branch on
    `isinstance(field, dict)` when building the result expression."""
    output_obj = main_def.get('output')
    if not output_obj:
        raise CurationError(f"intent '{nsid}': 'returns' declared but the lexicon has no output")
    schema = output_obj.get('schema', {})

    if output_path in (None, '', '.'):
        if schema.get('type') != 'ref':
            raise CurationError(
                f"intent '{nsid}': outputPath omitted/'.' requires the output schema to be a "
                "$ref (whole-output single-entity mode) — use an explicit outputPath field name "
                "for an inline-object output instead"
            )
        return schema['ref'], 'single', None

    props = schema.get('properties', {})

    # One-level array-element nesting: "feed.post" reads the required array
    # field `feed` (of $ref items, e.g. feedViewPost) and, for each element,
    # extracts a required $ref leaf field (e.g. `post`, a postView ref) —
    # mirrors the entity display/properties nested-ref-path extension in
    # STEP 1, but for a query's array output instead of an entity's stored
    # properties. Deeper paths and non-ref leaves are hard errors, same
    # rationale as the entity-side extension.
    if '.' in output_path:
        parts = output_path.split('.')
        if len(parts) != 2 or not parts[0] or not parts[1]:
            raise CurationError(
                f"intent '{nsid}': outputPath '{output_path}' is not a valid array-element nested "
                "path — only '<arrayField>.<leafRefField>' one level deep is supported"
            )
        array_field, leaf_field = parts
        if array_field not in props:
            raise CurationError(f"intent '{nsid}': outputPath '{output_path}': '{array_field}' not found in output properties")
        if array_field not in schema.get('required', []):
            raise CurationError(f"intent '{nsid}': outputPath '{output_path}': '{array_field}' must be a required output field")
        array_prop = props[array_field]
        if array_prop.get('type') != 'array':
            raise CurationError(f"intent '{nsid}': outputPath '{output_path}': '{array_field}' must be an array")
        item = array_prop.get('items', {})
        if item.get('type') != 'ref':
            raise CurationError(f"intent '{nsid}': outputPath '{output_path}': '{array_field}' array items must be $ref")
        # The item type (e.g. feedViewPost) may live in a different lexicon
        # file than the intent itself (getTimeline vs feed/defs.json) — its
        # OWN leaf refs (e.g. feedViewPost's local "#postView") must be
        # qualified against ITS lexicon id, not the intent's, or a bare local
        # ref resolves against the wrong file downstream.
        item_lex_id, _ = normalize_ref(item['ref'], nsid)
        item_def = lex_index.resolve_def(item['ref'], nsid)
        item_props = item_def.get('properties', {})
        if leaf_field not in item_props:
            qualified_item = lex_index.qualify(item['ref'], nsid)
            raise CurationError(
                f"intent '{nsid}': outputPath '{output_path}': leaf '{leaf_field}' not found on "
                f"array element type '{qualified_item}'"
            )
        if leaf_field not in item_def.get('required', []):
            raise CurationError(
                f"intent '{nsid}': outputPath '{output_path}': leaf '{leaf_field}' must be required "
                f"on array element type (array-element nesting requires a non-optional nested ref)"
            )
        leaf_prop = item_props[leaf_field]
        if leaf_prop.get('type') != 'ref':
            raise CurationError(
                f"intent '{nsid}': outputPath '{output_path}': leaf '{leaf_field}' must itself be a "
                "$ref — array-element nesting only supports ref leaves"
            )
        qualified_leaf_ref = lex_index.qualify(leaf_prop['ref'], item_lex_id)
        return qualified_leaf_ref, 'collection', {'array_field': array_field, 'leaf_field': leaf_field}

    if output_path not in props:
        raise CurationError(f"intent '{nsid}': outputPath '{output_path}' not found in output properties")
    if output_path not in schema.get('required', []):
        raise CurationError(f"intent '{nsid}': outputPath '{output_path}' must be a required output field")
    prop = props[output_path]
    if prop.get('type') == 'array':
        item = prop.get('items', {})
        if item.get('type') != 'ref':
            raise CurationError(f"intent '{nsid}': outputPath '{output_path}' array items must be $ref")
        return item['ref'], 'collection', output_path
    if prop.get('type') == 'ref':
        return prop['ref'], 'single', output_path
    raise CurationError(f"intent '{nsid}': outputPath '{output_path}' must be a $ref or an array of $ref")


# ---------------------------------------------------------------------------
# Intent curation
# ---------------------------------------------------------------------------

def resolve_intent_source(lex_index: LexiconIndex, nsid: str, kind: str) -> dict:
    lexicon = lex_index.get(nsid)
    main_def = lexicon.get('defs', {}).get('main', {})
    lex_type = main_def.get('type')

    if kind == 'query':
        if lex_type != 'query':
            raise CurationError(f"intent '{nsid}': manifest kind 'query' but lexicon main type is '{lex_type}'")
        params_obj = main_def.get('parameters', {})
        return {
            'lexicon': lexicon,
            'main_def': main_def,
            'properties': params_obj.get('properties', {}),
            'required': params_obj.get('required', []),
            'has_input': 'parameters' in main_def,
            'struct_name': 'Parameters',
        }

    if kind == 'procedure':
        if lex_type != 'procedure':
            raise CurationError(f"intent '{nsid}': manifest kind 'procedure' but lexicon main type is '{lex_type}'")
        if 'parameters' in main_def:
            raise CurationError(
                f"intent '{nsid}': procedures with BOTH `parameters` (query string) and `input` "
                "are not supported by app_intents_generator — curate `input` only"
            )
        input_obj = main_def.get('input', {})
        if input_obj and input_obj.get('encoding', 'application/json') != 'application/json':
            raise CurationError(f"intent '{nsid}': only application/json procedure input is supported")
        schema = input_obj.get('schema', {})
        if schema.get('type') == 'ref':
            raise CurationError(
                f"intent '{nsid}': procedure input is a $ref (not an inline object schema) — unsupported"
            )
        return {
            'lexicon': lexicon,
            'main_def': main_def,
            'properties': schema.get('properties', {}),
            'required': schema.get('required', []),
            'has_input': 'input' in main_def,
            'struct_name': 'Input',
        }

    raise CurationError(f"intent '{nsid}': unsupported kind '{kind}'")


def _clamp_bridge_template(prop: dict, bridge_info: dict) -> dict:
    """For a lexicon `integer` parameter carrying `minimum`/`maximum`, rewrite
    `bridge_info['bridge_expr_template']` so the emitted Swift clamps the
    intent-facing Int into the lexicon's declared range before it reaches the
    Parameters/Input constructor — an out-of-range Shortcuts value would
    otherwise reach the server as-is and come back a 400. Leaves `bridge_info`
    untouched for non-integer params or integers with no min/max declared.
    Does not touch the @Parameter's Swift type (still plain `Int`/`Int?`)."""
    if prop.get('type') != 'integer':
        return bridge_info
    lo = prop.get('minimum')
    hi = prop.get('maximum')
    if lo is None and hi is None:
        return bridge_info
    if lo is not None and hi is not None:
        clamp_template = f"min(max({{v}}, {lo}), {hi})"
    elif lo is not None:
        clamp_template = f"max({{v}}, {lo})"
    else:
        clamp_template = f"min({{v}}, {hi})"
    return {**bridge_info, 'bridge_expr_template': clamp_template}


def build_bridge_expr(param: dict) -> str:
    """Build the Swift argument expression for one curated parameter.

    `param['value_source']` is either the @Parameter's own name (plain
    curation) or `"<paramName>.<bridgeField>"` (a `parameterOverrides` entity
    resolution). When the @Parameter is Optional, bridging goes through
    `.map` (Optional.map is `rethrows`, so `try name.map { try Ctor($0) }` is
    valid Swift and only requires the outer `try` when the inner call
    throws); when non-Optional, the bridge template is substituted directly
    and inlined (Swift allows an inline `try` on a throwing sub-expression
    inside a larger non-throwing call, e.g. `Foo(x: try bar())`).
    """
    template = param['bridge_template']
    receiver = param['name']
    base = param['value_source']
    is_override = base != receiver
    field = base.split('.', 1)[1] if is_override else None

    if param['optional']:
        if template == '{v}' and not is_override:
            return receiver
        v = '$0' if not is_override else f"$0.{field}"
        inner = template.format(v=v)
        prefix = 'try ' if param['needs_throws'] else ''
        return f"{prefix}{receiver}.map {{ {inner} }}"

    v = base if is_override else receiver
    return template.format(v=v)


def curate_parameters(nsid: str, intent_struct_name: str, source: dict, intent_cfg: dict):
    excluded = intent_cfg.get('excludeParameters', [])
    overrides_meta = intent_cfg.get('parameters', {})
    overrides_resolve = intent_cfg.get('parameterOverrides', {})

    # Every name referenced by excludeParameters/parameters/parameterOverrides must
    # be an actual lexicon parameter — otherwise a typo (e.g. excluding "terms"
    # instead of "term") silently no-ops instead of curating what the author meant.
    known_names = source['properties'].keys()
    for field_name, names in (
        ('excludeParameters', excluded),
        ('parameters', overrides_meta),
        ('parameterOverrides', overrides_resolve),
    ):
        for name in names:
            if name not in known_names:
                raise CurationError(
                    f"intent '{nsid}': {field_name} references unknown parameter '{name}' "
                    f"(lexicon '{nsid}' has: {', '.join(known_names) or '(none)'})"
                )

    for name in excluded:
        if name in source['required']:
            raise CurationError(f"intent '{nsid}': excludeParameters cannot drop required field '{name}'")

    curated = []
    enums = []  # list of (enum_type_name, [knownValues...])

    for name, prop in source['properties'].items():
        if name in excluded:
            continue
        is_required = name in source['required']
        meta = overrides_meta.get(name, {})
        _check_known_keys(meta, _PARAMETER_META_KEYS, f"intent '{nsid}' parameters.{name}")
        request_value = bool(meta.get('requestValue', False))
        # requestValue forces the @Parameter to be non-Optional (so Shortcuts/Siri
        # always prompts for it) even though the lexicon marks the field optional.
        # A lexicon-required field is always non-Optional regardless of this flag.
        emit_optional = (not is_required) and not request_value

        resolve = overrides_resolve.get(name)
        if resolve:
            _check_known_keys(resolve, _PARAMETER_OVERRIDE_KEYS, f"intent '{nsid}' parameterOverrides.{name}")
            resolve_as = resolve.get('resolveAs')
            bridge_field = resolve.get('bridge')
            if not resolve_as or not bridge_field:
                raise CurationError(
                    f"intent '{nsid}' parameter '{name}': parameterOverrides needs both "
                    "'resolveAs' and 'bridge'"
                )
            try:
                bridge_info = intent_facing_type(prop)
            except CurationError as e:
                raise CurationError(f"intent '{nsid}' parameter '{name}': {e}") from e
            swift_type = resolve_as
            value_source = f"{name}.{bridge_field}"
        else:
            enum_type_name = None
            if prop.get('type') == 'string' and prop.get('knownValues'):
                enum_type_name = f"{intent_struct_name}{convert_to_camel_case(name)}Option"
            try:
                bridge_info = intent_facing_type(prop, enum_type_name=enum_type_name)
            except CurationError as e:
                raise CurationError(f"intent '{nsid}' parameter '{name}': {e}") from e
            bridge_info = _clamp_bridge_template(prop, bridge_info)
            swift_type = bridge_info['swift_type']
            value_source = name
            if bridge_info.get('is_enum'):
                enums.append((enum_type_name, prop['knownValues']))

        title = meta.get('title') or prop.get('description') or name
        curated.append({
            'name': name,
            'title': _escape_swift_string(title),
            'swift_type': swift_type,
            'optional': emit_optional,
            'bridge_template': bridge_info['bridge_expr_template'],
            'needs_throws': bridge_info['needs_throws'],
            'value_source': value_source,
        })

    return curated, enums


def resolve_returns(lex_index: LexiconIndex, nsid: str, main_def: dict, returns_cfg: dict, entities_by_name: dict):
    entity_name = returns_cfg.get('entity')
    if not entity_name or entity_name not in entities_by_name:
        raise CurationError(
            f"intent '{nsid}': returns.entity '{entity_name}' is not declared in appIntents.entities"
        )
    output_path = returns_cfg.get('outputPath')
    ref, mode, field = resolve_output_element_ref(lex_index, nsid, main_def, output_path)
    return {'entity': entity_name, 'ref': ref, 'mode': mode, 'field': field}


def resolve_scalar_return(nsid: str, main_def: dict, returns_cfg: dict) -> dict:
    """Resolve `returns.scalar` — a query whose useful output is a single
    lexicon integer/boolean/number field (e.g. `getUnreadCount`'s `count`)
    rather than a $ref, so it can't go through the entity-returning path at
    all. Requires an explicit, required, top-level `outputPath` naming that
    field; no nesting/array support (a manifest author who needs one of those
    should use `returns.entity` + `outputPath` instead)."""
    scalar_type = returns_cfg.get('scalar')
    output_path = returns_cfg.get('outputPath')
    if not output_path:
        raise CurationError(f"intent '{nsid}': returns.scalar requires an explicit outputPath")
    output_obj = main_def.get('output')
    if not output_obj:
        raise CurationError(f"intent '{nsid}': 'returns' declared but the lexicon has no output")
    schema = output_obj.get('schema', {})
    props = schema.get('properties', {})
    if output_path not in props:
        raise CurationError(f"intent '{nsid}': returns.outputPath '{output_path}' not found in output properties")
    if output_path not in schema.get('required', []):
        raise CurationError(
            f"intent '{nsid}': returns.outputPath '{output_path}' must be a required output field "
            "for a scalar return"
        )
    prop = props[output_path]
    prop_type = prop.get('type')
    expected_swift = _SCALAR_RETURN_TYPES.get(prop_type)
    if expected_swift is None:
        raise CurationError(
            f"intent '{nsid}': returns.outputPath '{output_path}' has lexicon type '{prop_type}', "
            "which is not a supported scalar return (integer/boolean/number only)"
        )
    if expected_swift != scalar_type:
        raise CurationError(
            f"intent '{nsid}': returns.scalar '{scalar_type}' does not match outputPath "
            f"'{output_path}''s lexicon-derived Swift type '{expected_swift}'"
        )
    return {'swift_type': expected_swift, 'field': output_path}


def resolve_intent(lex_index: LexiconIndex, intent_cfg: dict, entities_by_name: dict, idx: int) -> dict:
    _check_known_keys(intent_cfg, _INTENT_KEYS, f"appIntents.intents[{idx}]")
    nsid = intent_cfg.get('id')
    kind = intent_cfg.get('kind')
    struct_name = intent_cfg.get('structName')
    if not nsid or not kind or not struct_name:
        raise CurationError(
            f"appIntents.intents[{idx}]: every intent needs 'id', 'kind', and 'structName' "
            f"(got: id={nsid!r}, kind={kind!r}, structName={struct_name!r})"
        )
    if kind == 'recordWrite':
        return resolve_record_write(lex_index, intent_cfg, entities_by_name, idx)
    if kind not in ('query', 'procedure'):
        raise CurationError(f"intent '{nsid}': unknown kind '{kind}'")

    source = resolve_intent_source(lex_index, nsid, kind)
    main_def = source['main_def']

    curated_params, enums = curate_parameters(nsid, struct_name, source, intent_cfg)

    returns_cfg = intent_cfg.get('returns')
    if kind == 'query' and not returns_cfg:
        raise CurationError(f"intent '{nsid}': query intents must declare 'returns'")
    returns = None
    scalar_return = None
    if returns_cfg:
        _check_known_keys(returns_cfg, _RETURNS_KEYS, f"intent '{nsid}' returns")
        if returns_cfg.get('entity') and returns_cfg.get('scalar'):
            raise CurationError(f"intent '{nsid}': returns cannot declare both 'entity' and 'scalar'")
        if returns_cfg.get('scalar'):
            scalar_return = resolve_scalar_return(nsid, main_def, returns_cfg)
        else:
            returns = resolve_returns(lex_index, nsid, main_def, returns_cfg, entities_by_name)

    has_output = 'output' in main_def
    if (returns or scalar_return) and not has_output:
        raise CurationError(f"intent '{nsid}': returns declared but lexicon has no output")

    if source['has_input']:
        args = ', '.join(f"{p['name']}: {build_bridge_expr(p)}" for p in curated_params)
        params_expr = f"{convert_to_camel_case(nsid)}.{source['struct_name']}({args})"
        call_args = 'input: params'
    else:
        params_expr = None
        call_args = ''
    client_call = f"{client_path(nsid)}({call_args})"

    returns_type = None
    result_expr = None
    if returns:
        if returns['mode'] == 'collection':
            returns_type = f"[{returns['entity']}]"
            if isinstance(returns['field'], dict):
                array_field = returns['field']['array_field']
                leaf_field = returns['field']['leaf_field']
                result_expr = f"output.{array_field}.map {{ {returns['entity']}(from: $0.{leaf_field}) }}"
            else:
                result_expr = f"output.{returns['field']}.map {{ {returns['entity']}(from: $0) }}"
        else:
            returns_type = returns['entity']
            if returns['field']:
                result_expr = f"{returns['entity']}(from: output.{returns['field']})"
            else:
                result_expr = f"{returns['entity']}(from: output)"
    elif scalar_return:
        returns_type = scalar_return['swift_type']
        result_expr = f"output.{scalar_return['field']}"

    dialog_override = intent_cfg.get('dialog')
    if dialog_override is not None:
        if not isinstance(dialog_override, str) or not dialog_override:
            raise CurationError(f"intent '{nsid}': 'dialog' must be a non-empty string")
        if returns:
            raise CurationError(
                f"intent '{nsid}': 'dialog' overrides are only supported for scalar returns and "
                "void procedures — entity-returning dialogs are derived automatically"
            )

    result_block = _build_result_block(
        nsid=nsid,
        client_call=client_call,
        has_output=has_output,
        returns=returns,
        scalar_return=scalar_return,
        result_expr=result_expr,
        dialog_override=dialog_override,
    )

    return {
        'source_nsid': nsid,
        'kind': kind,
        'struct_name': struct_name,
        'title': _escape_swift_string(intent_cfg.get('title') or struct_name),
        'description': _escape_swift_string(intent_cfg.get('description', '')),
        'confirmation': bool(intent_cfg.get('confirmation', False)),
        'parameters': curated_params,
        'enums': enums,
        'has_input': source['has_input'],
        'params_expr': params_expr,
        'client_call': client_call,
        'returns': returns,
        'returns_type': returns_type,
        'result_block': result_block,
    }


def _build_result_block(nsid, client_call, has_output, returns, scalar_return,
                        result_expr, dialog_override) -> str:
    """The Swift statements after the client is bound: issue the call, map the
    output, and return `.result(...)` with a spoken IntentDialog. Every intent
    provides a dialog so Siri has something to say — collection/single entity
    dialogs are derived from the returned entities' displayRepresentation;
    scalar and void dialogs default to generic text overridable per intent via
    the manifest `dialog` key ("{value}" interpolates the scalar result)."""
    indent = '        '

    if returns:
        noun = _display_noun(_entity_display_type_name(returns['entity']))
        noun_plural = noun + 's'
        if returns['mode'] == 'collection':
            found_line = (
                f'Found \\(value.count) \\(value.count == 1 ? "{noun}" : "{noun_plural}"). '
                'First: \\(String(localized: first.displayRepresentation.title)).'
            )
            return (
                f"{indent}let output = try unwrapIntentResponse(await client.{client_call})\n"
                f"{indent}let value = {result_expr}\n"
                f"{indent}let dialog: IntentDialog\n"
                f"{indent}if let first = value.first {{\n"
                f'{indent}    dialog = IntentDialog(stringLiteral: "{found_line}")\n'
                f"{indent}}} else {{\n"
                f'{indent}    dialog = IntentDialog(stringLiteral: "No {noun_plural} found.")\n'
                f"{indent}}}\n"
                f"{indent}return .result(value: value, dialog: dialog)"
            )
        label = _entity_display_type_name(returns['entity'])
        return (
            f"{indent}let output = try unwrapIntentResponse(await client.{client_call})\n"
            f"{indent}let value = {result_expr}\n"
            f"{indent}return .result(value: value, dialog: IntentDialog(stringLiteral: "
            f'"{label}: \\(String(localized: value.displayRepresentation.title))"))'
        )

    if scalar_return:
        template = dialog_override or 'Result: {value}'
        if '{value}' in template:
            prefix, _, suffix = template.partition('{value}')
            dialog_text = f"{_escape_swift_string(prefix)}\\(value){_escape_swift_string(suffix)}"
        else:
            dialog_text = _escape_swift_string(template)
        return (
            f"{indent}let output = try unwrapIntentResponse(await client.{client_call})\n"
            f"{indent}let value = {result_expr}\n"
            f"{indent}return .result(value: value, dialog: IntentDialog(stringLiteral: \"{dialog_text}\"))"
        )

    done_text = _escape_swift_string(dialog_override or 'Done.')
    if has_output:
        return (
            f"{indent}_ = try unwrapIntentResponse(await client.{client_call})\n"
            f"{indent}return .result(dialog: IntentDialog(stringLiteral: \"{done_text}\"))"
        )
    # No-output procedures return a bare response code from the generated
    # client — check it instead of discarding it so failures actually throw.
    return (
        f"{indent}let responseCode = try await client.{client_call}\n"
        f"{indent}guard (200..<300).contains(responseCode) else {{\n"
        f"{indent}    throw IntentError.httpError(responseCode)\n"
        f"{indent}}}\n"
        f"{indent}return .result(dialog: IntentDialog(stringLiteral: \"{done_text}\"))"
    )


def resolve_record_write(lex_index: LexiconIndex, intent_cfg: dict, entities_by_name: dict, idx: int) -> dict:
    """Resolve a `kind: "recordWrite"` intent: a com.atproto.repo record
    create/delete driven by a hydrate-then-write pattern. The intent takes ONE
    entity parameter (the subject), re-fetches the subject's fresh view via the
    declared hydrate endpoint (which supplies both the strongRef `cid` and the
    viewer state), then either creates the record (skipping when the viewer URI
    at `viewerPath` shows it already exists) or deletes the record named by
    that viewer URI (skipping when absent). `id` is the RECORD NSID (e.g.
    app.bsky.feed.like), shared by the create and delete intents for one
    collection — `structName` uniqueness is what tells them apart."""
    nsid = intent_cfg['id']
    struct_name = intent_cfg['structName']
    context = f"intent '{nsid}' ({struct_name})"

    rw = intent_cfg.get('recordWrite')
    if not rw:
        raise CurationError(f"{context}: kind 'recordWrite' requires a 'recordWrite' object")
    _check_known_keys(rw, _RECORD_WRITE_KEYS, f"{context} recordWrite")
    if intent_cfg.get('returns') is not None:
        raise CurationError(f"{context}: recordWrite intents cannot declare 'returns' (dialog-only)")
    if intent_cfg.get('dialog') is not None:
        raise CurationError(f"{context}: use recordWrite.dialog, not the top-level 'dialog' key")
    for unsupported in ('parameters', 'excludeParameters', 'parameterOverrides'):
        if intent_cfg.get(unsupported) is not None:
            raise CurationError(f"{context}: '{unsupported}' is not supported on recordWrite intents")

    action = rw.get('action')
    if action not in ('create', 'delete'):
        raise CurationError(f"{context}: recordWrite.action must be 'create' or 'delete' (got {action!r})")

    # --- Record lexicon shape ---
    lexicon = lex_index.get(nsid)
    main_def = lexicon.get('defs', {}).get('main', {})
    if main_def.get('type') != 'record':
        raise CurationError(
            f"{context}: recordWrite id must name a record lexicon (main type is '{main_def.get('type')}')"
        )
    record_schema = main_def.get('record', {})
    record_props = record_schema.get('properties', {})
    record_required = record_schema.get('required', [])
    extra_required = [r for r in record_required if r not in ('subject', 'createdAt')]
    if extra_required:
        raise CurationError(
            f"{context}: record requires fields beyond subject/createdAt ({', '.join(extra_required)}) "
            "— unsupported (only subject+createdAt records can be synthesized)"
        )
    if 'subject' not in record_props or 'createdAt' not in record_props:
        raise CurationError(f"{context}: recordWrite requires the record to declare 'subject' and 'createdAt'")

    # --- Subject: manifest kind must match the record's declared subject shape ---
    subject_cfg = rw.get('subject') or {}
    _check_known_keys(subject_cfg, _RW_SUBJECT_KEYS, f"{context} recordWrite.subject")
    subject_kind = subject_cfg.get('kind')
    subject_schema = record_props['subject']
    if subject_kind == 'strongRef':
        ref_target = normalize_ref(subject_schema.get('ref', ''), nsid)[0] if subject_schema.get('type') == 'ref' else None
        if ref_target != 'com.atproto.repo.strongRef':
            raise CurationError(
                f"{context}: subject.kind 'strongRef' but the record's subject is not a "
                "com.atproto.repo.strongRef ref"
            )
    elif subject_kind == 'did':
        if subject_schema.get('type') != 'string' or subject_schema.get('format') != 'did':
            raise CurationError(
                f"{context}: subject.kind 'did' but the record's subject is not a string with format did"
            )
    else:
        raise CurationError(f"{context}: recordWrite.subject.kind must be 'strongRef' or 'did'")

    param_cfg = subject_cfg.get('parameter') or {}
    _check_known_keys(param_cfg, _RW_PARAM_KEYS, f"{context} recordWrite.subject.parameter")
    param_name = param_cfg.get('name')
    entity_name = param_cfg.get('entity')
    if not param_name or not entity_name:
        raise CurationError(f"{context}: recordWrite.subject.parameter needs 'name' and 'entity'")
    if entity_name not in entities_by_name:
        raise CurationError(
            f"{context}: recordWrite.subject.parameter.entity '{entity_name}' is not declared in "
            "appIntents.entities"
        )
    param_title = param_cfg.get('title') or param_name

    # --- Hydrate endpoint: array-of-identifiers query returning the subject's view ---
    hydrate_cfg = subject_cfg.get('hydrate') or {}
    _check_known_keys(hydrate_cfg, _RW_HYDRATE_KEYS, f"{context} recordWrite.subject.hydrate")
    h_nsid = hydrate_cfg.get('nsid')
    h_param = hydrate_cfg.get('param')
    h_results = hydrate_cfg.get('resultsPath')
    if not h_nsid or not h_param or not h_results:
        raise CurationError(f"{context}: recordWrite.subject.hydrate needs 'nsid', 'param', and 'resultsPath'")
    h_main = lex_index.get(h_nsid).get('defs', {}).get('main', {})
    if h_main.get('type') != 'query':
        raise CurationError(f"{context}: hydrate.nsid '{h_nsid}' must be a query")
    h_params_obj = h_main.get('parameters', {})
    h_props = h_params_obj.get('properties', {})
    if h_param not in h_props:
        raise CurationError(f"{context}: hydrate.param '{h_param}' not found in '{h_nsid}' parameters")
    other_required = [r for r in h_params_obj.get('required', []) if r != h_param]
    if other_required:
        raise CurationError(
            f"{context}: hydrate nsid '{h_nsid}' has other required parameters {other_required}; unsupported"
        )
    h_prop = h_props[h_param]
    if h_prop.get('type') != 'array':
        raise CurationError(f"{context}: hydrate.param '{h_param}' must be an array of identifiers")
    try:
        item_bridge = intent_facing_type(h_prop.get('items', {}))
    except CurationError as e:
        raise CurationError(f"{context}: hydrate.param '{h_param}' items: {e}") from e
    if item_bridge['swift_type'] != 'String':
        raise CurationError(f"{context}: hydrate.param '{h_param}' items must be String-typed")

    view_ref, _ = _results_ref(lex_index, h_nsid, h_main, h_results)
    view_def = lex_index.resolve_def(view_ref, h_nsid)
    view_props = view_def.get('properties', {})
    view_required = view_def.get('required', [])
    view_qualified = lex_index.qualify(view_ref, h_nsid)

    # --- Subject construction from the hydrated view ---
    if subject_kind == 'strongRef':
        for field, fmt in (('uri', 'at-uri'), ('cid', 'cid')):
            fp = view_props.get(field)
            if fp is None or field not in view_required or fp.get('type') != 'string' or fp.get('format') != fmt:
                raise CurationError(
                    f"{context}: hydrated view '{view_qualified}' must declare required '{field}' "
                    f"(string, format {fmt}) to build a strongRef subject"
                )
        subject_expr = 'ComAtprotoRepoStrongRef(uri: view.uri, cid: view.cid)'
    else:
        fp = view_props.get('did')
        if fp is None or 'did' not in view_required or fp.get('type') != 'string' or fp.get('format') != 'did':
            raise CurationError(
                f"{context}: hydrated view '{view_qualified}' must declare required 'did' "
                "(string, format did) to build a did subject"
            )
        subject_expr = 'view.did'

    # --- viewerPath: '<viewerField>.<leaf>' resolving to an optional at-uri ---
    viewer_path = rw.get('viewerPath')
    if not viewer_path or viewer_path.count('.') != 1:
        raise CurationError(
            f"{context}: recordWrite.viewerPath must be '<viewerField>.<leaf>' (e.g. 'viewer.like')"
        )
    viewer_field, viewer_leaf = viewer_path.split('.')
    vf = view_props.get(viewer_field)
    if vf is None or vf.get('type') != 'ref':
        raise CurationError(
            f"{context}: viewerPath '{viewer_path}': '{viewer_field}' must be a $ref field on "
            f"'{view_qualified}'"
        )
    owner_nsid = view_qualified.split('#', 1)[0]
    viewer_def = lex_index.resolve_def(vf['ref'], owner_nsid)
    leaf_prop = viewer_def.get('properties', {}).get(viewer_leaf)
    if leaf_prop is None or leaf_prop.get('type') != 'string' or leaf_prop.get('format') != 'at-uri':
        raise CurationError(
            f"{context}: viewerPath '{viewer_path}': leaf '{viewer_leaf}' must be a string with "
            f"format at-uri on '{lex_index.qualify(vf['ref'], owner_nsid)}'"
        )
    viewer_optional = viewer_field not in view_required
    leaf_optional = viewer_leaf not in viewer_def.get('required', [])
    if not (viewer_optional or leaf_optional):
        raise CurationError(
            f"{context}: viewerPath '{viewer_path}' resolves to a non-optional field — recordWrite "
            "needs an optional viewer URI to distinguish already-done from to-do"
        )
    viewer_chain = f"view.{viewer_field}{'?' if viewer_optional else ''}.{viewer_leaf}"

    # --- Dialogs ---
    dialog_cfg = rw.get('dialog') or {}
    _check_known_keys(dialog_cfg, _RW_DIALOG_KEYS, f"{context} recordWrite.dialog")
    success_dialog = _escape_swift_string(dialog_cfg.get('success') or 'Done.')
    already_dialog = _escape_swift_string(dialog_cfg.get('alreadyDone') or 'Nothing to change.')

    # --- Record constructor args, in lexicon property order (extras are all
    # optional per the required-subset check above and synthesized as nil) ---
    args = []
    for pname in record_props:
        if pname == 'subject':
            args.append(f"subject: {subject_expr}")
        elif pname == 'createdAt':
            args.append("createdAt: ATProtocolDate(date: Date())")
        else:
            args.append(f"{pname}: nil")
    record_expr = f"{convert_to_camel_case(nsid)}({', '.join(args)})"

    # Bridge templates already carry their own inline `try` when throwing (see
    # build_bridge_expr) — substitute the entity id directly.
    item_expr = item_bridge['bridge_expr_template'].format(v=f"{param_name}.id")
    hydrate_call = (
        f"{client_path(h_nsid)}(input: {convert_to_camel_case(h_nsid)}.Parameters({h_param}: [{item_expr}]))"
    )

    noun = _display_noun(_entity_display_type_name(entity_name))

    return {
        'source_nsid': nsid,
        'kind': 'recordWrite',
        'struct_name': struct_name,
        'title': _escape_swift_string(intent_cfg.get('title') or struct_name),
        'description': _escape_swift_string(intent_cfg.get('description', '')),
        'confirmation': bool(intent_cfg.get('confirmation', False)),
        'enums': [],
        'returns': None,
        'record_write': {
            'action': action,
            'param_name': param_name,
            'param_title': _escape_swift_string(param_title),
            'entity': entity_name,
            'hydrate_call': hydrate_call,
            'results_path': h_results,
            'viewer_chain': viewer_chain,
            'record_expr': record_expr,
            'record_nsid': nsid,
            'success_dialog': success_dialog,
            'already_dialog': already_dialog,
            'missing_message': _escape_swift_string(f"Catbird couldn't load that {noun}."),
        },
    }


def _split_nested_property(entity_name: str, prop_name: str):
    """Split a manifest `properties`/`display` entry into a one-level nested
    ref path, or return `(None, None)` for a plain (non-dotted) scalar name.

    Only exactly one dot is supported ("author.handle") — deeper paths
    ("a.b.c") and empty segments (".foo", "foo.") hard-fail immediately so a
    manifest typo doesn't silently resolve to nothing."""
    if '.' not in prop_name:
        return None, None
    parts = prop_name.split('.')
    if len(parts) != 2 or not parts[0] or not parts[1]:
        raise CurationError(
            f"entity '{entity_name}': property '{prop_name}' is not a valid one-level ref path — "
            "only paths of the form '<ref>.<leaf>' (e.g. 'author.handle') are supported"
        )
    return parts[0], parts[1]


def _nested_swift_property_name(ref_name: str, leaf_name: str) -> str:
    """The Swift-safe stored-property identifier for a nested ref path
    ("author" + "handle" -> "authorHandle"). Dots are not valid in Swift
    identifiers, so the dot-path manifest key (used for matching `display`/
    `properties` config) and the generated Swift field name are kept as two
    separate strings — see `resolve_entity`."""
    return ref_name + leaf_name[0].upper() + leaf_name[1:]


def _resolve_nested_property(lex_index: LexiconIndex, entity_name: str, prop_name: str,
                              ref_name: str, leaf_name: str, src: dict):
    """Resolve one source view's contribution to a one-level nested ref path
    property (e.g. `author.handle` on a `postView`-sourced entity).

    Returns `None` when `ref_name` itself is absent from this source's schema
    (treated the same as a missing direct property — optional, synthesized as
    `nil` — since real sibling view defs can differ). Any OTHER shape problem
    (the field isn't a $ref, the leaf isn't found on the ref'd def, the leaf
    isn't a supported scalar, or the leaf is itself another $ref) is a hard
    CurationError: those indicate a manifest authoring mistake, not a benign
    cross-view difference, per the "hard-fail on deeper nesting / non-scalar
    leaf / nested-in-nested refs" rule.
    """
    props = src['schema'].get('properties', {})
    if ref_name not in props:
        return None

    ref_prop_schema = props[ref_name]
    if ref_prop_schema.get('type') != 'ref':
        raise CurationError(
            f"entity '{entity_name}': property '{prop_name}': '{ref_name}' in source "
            f"'{src['qualified']}' has type '{ref_prop_schema.get('type')}', not 'ref' — nested "
            "dot-paths are only supported for $ref fields"
        )

    owner_nsid = src['qualified'].split('#', 1)[0]
    nested_def = lex_index.resolve_def(ref_prop_schema['ref'], owner_nsid)
    nested_props = nested_def.get('properties', {})
    if leaf_name not in nested_props:
        qualified_nested = lex_index.qualify(ref_prop_schema['ref'], owner_nsid)
        raise CurationError(
            f"entity '{entity_name}': property '{prop_name}': leaf '{leaf_name}' not found on "
            f"ref'd type '{qualified_nested}' (source '{src['qualified']}')"
        )

    leaf_schema = nested_props[leaf_name]
    extraction = intent_entity_extraction(leaf_schema)
    if extraction is None:
        raise CurationError(
            f"entity '{entity_name}': property '{prop_name}': leaf '{leaf_name}' on "
            f"'{lex_index.qualify(ref_prop_schema['ref'], owner_nsid)}' has an unsupported type for "
            "entity projection (only String/Date/URL-bridgeable scalars are supported one level "
            "deep — nested-in-nested $refs are not supported)"
        )

    ref_optional = ref_name not in src['schema'].get('required', [])
    leaf_optional = leaf_name not in nested_def.get('required', [])
    is_url = extraction['swift_type'] == 'URL'
    # Optionality composes: either link being optional (or a URI's inherently-
    # Optional `.url` accessor) makes the whole projected value Optional.
    source_optional = ref_optional or leaf_optional or is_url

    base_chain = f"view.{ref_name}" + ('?' if ref_optional else '') + f".{leaf_name}"
    template = extraction['optional_chain_template'] if source_optional else extraction['direct_template']

    return {
        'swift_type': extraction['swift_type'],
        'optional': source_optional,
        'expr': template.format(v=base_chain),
    }


# ---------------------------------------------------------------------------
# Entity curation
# ---------------------------------------------------------------------------

def _build_string_query_body(lex_index: LexiconIndex, entity_name: str, query_cfg: dict) -> str:
    nsid = query_cfg['nsid']
    param_name = query_cfg['param']
    results_path = query_cfg['resultsPath']
    lexicon = lex_index.get(nsid)
    main_def = lexicon.get('defs', {}).get('main', {})
    if main_def.get('type') != 'query':
        raise CurationError(f"entity '{entity_name}': query.nsid '{nsid}' must be a query")

    params_obj = main_def.get('parameters', {})
    properties = params_obj.get('properties', {})
    required = params_obj.get('required', [])
    if param_name not in properties:
        raise CurationError(f"entity '{entity_name}': query.param '{param_name}' not found in '{nsid}' parameters")
    other_required = [r for r in required if r != param_name]
    if other_required:
        raise CurationError(
            f"entity '{entity_name}': query nsid '{nsid}' has other required parameters "
            f"{other_required}; unsupported for entity string queries"
        )

    try:
        bridge = intent_facing_type(properties[param_name])
    except CurationError as e:
        raise CurationError(f"entity '{entity_name}': query.param '{param_name}': {e}") from e
    if bridge['swift_type'] != 'String':
        raise CurationError(
            f"entity '{entity_name}': query.param '{param_name}' must be String-typed for a string query"
        )
    value_expr = bridge['bridge_expr_template'].format(v='string')

    _ref, _mode = _results_ref(lex_index, nsid, main_def, results_path)

    call = f"client.{client_path(nsid)}(input: {convert_to_camel_case(nsid)}.Parameters({param_name}: {value_expr}))"
    return (
        "        let did = IntentAccountResolver.activeDID()\n"
        "        let client = try await IntentClientProvider.shared.client(for: did)\n"
        f"        let output = try unwrapIntentResponse(await {call})\n"
        f"        return output.{results_path}.map {{ {entity_name}(from: $0) }}"
    )


def _build_by_ids_body(lex_index: LexiconIndex, entity_name: str, by_ids_cfg: dict) -> str:
    nsid = by_ids_cfg['nsid']
    param_name = by_ids_cfg['param']
    results_path = by_ids_cfg['resultsPath']
    lexicon = lex_index.get(nsid)
    main_def = lexicon.get('defs', {}).get('main', {})
    if main_def.get('type') != 'query':
        raise CurationError(f"entity '{entity_name}': query.byIds.nsid '{nsid}' must be a query")

    params_obj = main_def.get('parameters', {})
    properties = params_obj.get('properties', {})
    required = params_obj.get('required', [])
    if param_name not in properties:
        raise CurationError(f"entity '{entity_name}': byIds.param '{param_name}' not found in '{nsid}' parameters")
    other_required = [r for r in required if r != param_name]
    if other_required:
        raise CurationError(
            f"entity '{entity_name}': byIds nsid '{nsid}' has other required parameters "
            f"{other_required}; unsupported"
        )

    prop = properties[param_name]
    if prop.get('type') != 'array':
        raise CurationError(f"entity '{entity_name}': byIds.param '{param_name}' must be an array")
    try:
        item_bridge = intent_facing_type(prop.get('items', {}))
    except CurationError as e:
        raise CurationError(f"entity '{entity_name}': byIds.param '{param_name}' items: {e}") from e
    if item_bridge['swift_type'] != 'String':
        raise CurationError(f"entity '{entity_name}': byIds.param '{param_name}' items must be String-typed")
    item_expr = item_bridge['bridge_expr_template'].format(v='$0')
    map_prefix = 'try ' if item_bridge['needs_throws'] else ''

    _ref, _mode = _results_ref(lex_index, nsid, main_def, results_path)

    client_call = f"client.{client_path(nsid)}"
    params_ctor = f"{convert_to_camel_case(nsid)}.Parameters"

    # The lexicon caps how many identifiers a single call accepts (e.g.
    # getProfiles.actors / getPosts.uris both maxLength: 25). Read that cap
    # from the lexicon rather than hardcoding it, and when present, chunk
    # `identifiers` into request-sized batches, issuing one client call per
    # chunk and concatenating results in order. Endpoints with no maxLength
    # (e.g. getFeedGenerators.feeds) keep the original single-call form.
    max_length = prop.get('maxLength')
    if max_length:
        chunk_expr = f"{map_prefix}chunk.map {{ {item_expr} }}"
        call = f"{client_call}(input: {params_ctor}({param_name}: {chunk_expr}))"
        return (
            "        let did = IntentAccountResolver.activeDID()\n"
            "        let client = try await IntentClientProvider.shared.client(for: did)\n"
            f"        var results: [{entity_name}] = []\n"
            f"        for start in stride(from: 0, to: identifiers.count, by: {max_length}) {{\n"
            f"            let chunk = Array(identifiers[start..<min(start + {max_length}, identifiers.count)])\n"
            f"            let output = try unwrapIntentResponse(await {call})\n"
            f"            results.append(contentsOf: output.{results_path}.map {{ {entity_name}(from: $0) }})\n"
            "        }\n"
            "        return results"
        )

    array_expr = f"{map_prefix}identifiers.map {{ {item_expr} }}"
    call = f"{client_call}(input: {params_ctor}({param_name}: {array_expr}))"
    return (
        "        let did = IntentAccountResolver.activeDID()\n"
        "        let client = try await IntentClientProvider.shared.client(for: did)\n"
        f"        let output = try unwrapIntentResponse(await {call})\n"
        f"        return output.{results_path}.map {{ {entity_name}(from: $0) }}"
    )


def _build_fallback_by_ids_body(entity_name: str) -> str:
    """No `byIds` endpoint configured: resolve each identifier by re-running
    the string query and keeping the matching id. O(n) round trips — fine for
    the handful of identifiers Shortcuts/Siri typically resolves at once."""
    return (
        f"        var results: [{entity_name}] = []\n"
        "        for identifier in identifiers {\n"
        "            let matches = try await entities(matching: identifier)\n"
        "            if let match = matches.first(where: { $0.id == identifier }) {\n"
        "                results.append(match)\n"
        "            }\n"
        "        }\n"
        "        return results"
    )


def resolve_entity(lex_index: LexiconIndex, entity_cfg: dict, resolved_intents: list, idx: int) -> dict:
    _check_known_keys(entity_cfg, _ENTITY_KEYS, f"appIntents.entities[{idx}]")
    name = entity_cfg.get('name')
    source_ref = entity_cfg.get('source')
    identifier_prop = entity_cfg.get('identifier')
    if not name or not source_ref or not identifier_prop:
        raise CurationError(
            f"appIntents.entities[{idx}]: every entity needs 'name', 'source', and 'identifier' "
            f"(got: name={name!r}, source={source_ref!r}, identifier={identifier_prop!r})"
        )
    _PROPERTY_ENTRY_KEYS = {'path', 'title'}
    prop_cfgs = []
    for i, p in enumerate(entity_cfg.get('properties', [])):
        if isinstance(p, str):
            prop_cfgs.append({'path': p, 'title': None})
        elif isinstance(p, dict):
            _check_known_keys(p, _PROPERTY_ENTRY_KEYS, f"entity '{name}' properties[{i}]")
            if 'path' not in p:
                raise CurationError(f"entity '{name}' properties[{i}]: object entries need a 'path'")
            prop_cfgs.append({'path': p['path'], 'title': p.get('title')})
        else:
            raise CurationError(f"entity '{name}' properties[{i}]: must be a string or object")
    properties = [pc['path'] for pc in prop_cfgs]
    display_cfg = entity_cfg.get('display', {})
    _check_known_keys(display_cfg, _DISPLAY_KEYS, f"entity '{name}' display")
    query_cfg = entity_cfg.get('query')
    syncable = bool(entity_cfg.get('syncable', False))
    indexed = bool(entity_cfg.get('indexed', False))

    if not query_cfg:
        raise CurationError(f"entity '{name}': a 'query' config is required (no query-less entities yet)")
    _check_known_keys(query_cfg, _QUERY_KEYS, f"entity '{name}' query")
    if query_cfg.get('kind') != 'string':
        raise CurationError(f"entity '{name}': only query.kind == 'string' is supported")

    # --- Collect distinct source view refs (dict-as-insertion-ordered-set; see
    # module docstring on determinism — this MUST NOT be a `set()`) ---
    sources_seen = {}
    sources = []

    def add_source(raw_ref: str, owner_nsid: str):
        qualified = lex_index.qualify(raw_ref, owner_nsid)
        if qualified in sources_seen:
            return
        sources_seen[qualified] = True
        def_schema = lex_index.resolve_def(raw_ref, owner_nsid)
        sources.append({'qualified': qualified, 'raw_ref': raw_ref, 'schema': def_schema})

    # `source` is always authored fully-qualified ("<nsid>#<def>"), so the owner
    # passed here is never actually consulted for local-'#' resolution.
    add_source(source_ref, source_ref.split('#', 1)[0])

    q_nsid = query_cfg['nsid']
    q_main = lex_index.get(q_nsid).get('defs', {}).get('main', {})
    results_ref, _ = _results_ref(lex_index, q_nsid, q_main, query_cfg['resultsPath'])
    add_source(results_ref, q_nsid)

    by_ids_cfg = query_cfg.get('byIds')
    if by_ids_cfg:
        _check_known_keys(by_ids_cfg, _QUERY_BY_IDS_KEYS, f"entity '{name}' query.byIds")
        b_nsid = by_ids_cfg['nsid']
        b_main = lex_index.get(b_nsid).get('defs', {}).get('main', {})
        by_ids_ref, _ = _results_ref(lex_index, b_nsid, b_main, by_ids_cfg['resultsPath'])
        add_source(by_ids_ref, b_nsid)

    for resolved in resolved_intents:
        returns = resolved.get('returns')
        if returns and returns['entity'] == name:
            add_source(returns['ref'], resolved['source_nsid'])

    # --- Identifier: must be present, required, and String-bridgeable in every source ---
    id_extract_by_source = {}
    for src in sources:
        prop_schema = src['schema'].get('properties', {}).get(identifier_prop)
        if prop_schema is None:
            raise CurationError(
                f"entity '{name}': identifier property '{identifier_prop}' missing from source "
                f"'{src['qualified']}'"
            )
        if identifier_prop not in src['schema'].get('required', []):
            raise CurationError(
                f"entity '{name}': identifier property '{identifier_prop}' must be required in "
                f"every source view (optional in '{src['qualified']}')"
            )
        extraction = intent_entity_extraction(prop_schema)
        if extraction is None or extraction['swift_type'] != 'String':
            raise CurationError(
                f"entity '{name}': identifier property '{identifier_prop}' must resolve to a "
                f"String-bridgeable scalar (source '{src['qualified']}')"
            )
        id_extract_by_source[src['qualified']] = extraction['direct_template'].format(v=f"view.{identifier_prop}")

    # --- Stored properties ---
    resolved_props = []
    for prop_cfg in prop_cfgs:
        prop_name = prop_cfg['path']
        ref_name, leaf_name = _split_nested_property(name, prop_name)
        is_nested = ref_name is not None
        swift_name = _nested_swift_property_name(ref_name, leaf_name) if is_nested else prop_name

        swift_type = None
        overall_optional = False
        per_source_expr = {}
        for src in sources:
            if is_nested:
                result = _resolve_nested_property(lex_index, name, prop_name, ref_name, leaf_name, src)
                if result is None:
                    overall_optional = True
                    per_source_expr[src['qualified']] = 'nil'
                    continue
                if swift_type is None:
                    swift_type = result['swift_type']
                elif swift_type != result['swift_type']:
                    raise CurationError(
                        f"entity '{name}': property '{prop_name}' resolves to different Swift types "
                        f"across sources ('{swift_type}' vs '{result['swift_type']}' in "
                        f"'{src['qualified']}') — unsupported"
                    )
                if result['optional']:
                    overall_optional = True
                per_source_expr[src['qualified']] = result['expr']
                continue

            props = src['schema'].get('properties', {})
            if prop_name not in props:
                overall_optional = True
                per_source_expr[src['qualified']] = 'nil'
                continue
            prop_schema = props[prop_name]
            extraction = intent_entity_extraction(prop_schema)
            if extraction is None:
                raise CurationError(
                    f"entity '{name}': property '{prop_name}' has an unsupported type in source "
                    f"'{src['qualified']}' (only String/Date/URL-bridgeable scalars are supported)"
                )
            if swift_type is None:
                swift_type = extraction['swift_type']
            elif swift_type != extraction['swift_type']:
                raise CurationError(
                    f"entity '{name}': property '{prop_name}' resolves to different Swift types "
                    f"across sources ('{swift_type}' vs '{extraction['swift_type']}' in "
                    f"'{src['qualified']}') — unsupported"
                )
            source_optional = prop_name not in src['schema'].get('required', [])
            is_url = extraction['swift_type'] == 'URL'
            if source_optional or is_url:
                overall_optional = True
                template = extraction['optional_chain_template']
            else:
                template = extraction['direct_template']
            per_source_expr[src['qualified']] = template.format(v=f"view.{prop_name}")
        if swift_type is None:
            raise CurationError(f"entity '{name}': property '{prop_name}' not found in any resolved source view")
        resolved_props.append({
            'name': prop_name,
            'swift_name': swift_name,
            'swift_type': swift_type,
            'optional': overall_optional,
            'per_source_expr': per_source_expr,
            'title': prop_cfg['title'] or _default_property_title(swift_name),
        })

    # --- Custom (bridged) properties: manifest-authored Swift expressions for
    # fields the lexicon type system can't project (e.g. postView.record is
    # 'unknown'; the post text needs a runtime decode via a hand-written
    # helper in the app target). The expression sees `view`, the init param. ---
    for i, cp in enumerate(entity_cfg.get('customProperties', [])):
        _check_known_keys(cp, _CUSTOM_PROPERTY_KEYS, f"entity '{name}' customProperties[{i}]")
        cp_name, cp_type, cp_expr = cp.get('name'), cp.get('swiftType'), cp.get('expr')
        if not cp_name or not cp_type or not cp_expr:
            raise CurationError(
                f"entity '{name}' customProperties[{i}]: 'name', 'swiftType', and 'expr' are required"
            )
        resolved_props.append({
            'name': cp_name,
            'swift_name': cp_name,
            'swift_type': cp_type,
            'optional': bool(cp.get('optional', False)),
            'title': cp.get('title') or _default_property_title(cp_name),
            'per_source_expr': {src['qualified']: cp_expr for src in sources},
        })

    seen_swift_names = {}
    for p in resolved_props:
        if p['swift_name'] in seen_swift_names:
            raise CurationError(
                f"entity '{name}': properties '{seen_swift_names[p['swift_name']]}' and '{p['name']}' "
                f"both generate the Swift field name '{p['swift_name']}' — rename one to avoid a "
                "duplicate declaration"
            )
        seen_swift_names[p['swift_name']] = p['name']

    prop_names = [p['name'] for p in resolved_props]

    def find_prop(pname):
        for p in resolved_props:
            if p['name'] == pname:
                return p
        return None

    def display_prop(key, required=True):
        pname = display_cfg.get(key)
        if not pname:
            if required:
                raise CurationError(f"entity '{name}': display.{key} is required")
            return None
        if pname not in prop_names:
            raise CurationError(f"entity '{name}': display.{key} references undeclared property '{pname}'")
        return find_prop(pname)

    title_prop = display_prop('title')
    fallback_name = display_cfg.get('titleFallback')
    fallback_prop = None
    if fallback_name:
        if fallback_name not in prop_names:
            raise CurationError(
                f"entity '{name}': display.titleFallback references undeclared property '{fallback_name}'"
            )
        fallback_prop = find_prop(fallback_name)
    if title_prop['optional']:
        if not fallback_prop:
            raise CurationError(
                f"entity '{name}': display.title '{title_prop['name']}' is optional and needs a display.titleFallback"
            )
        if fallback_prop['optional']:
            # `title ?? fallback` only yields a non-Optional result when `fallback`
            # is itself guaranteed non-Optional in EVERY resolved source view. If
            # the fallback can also be nil in some source, `??` still produces an
            # Optional, and the string-interpolated title silently prints "nil"
            # instead of failing to compile.
            raise CurationError(
                f"entity '{name}': display.titleFallback '{fallback_prop['name']}' must be non-optional "
                "in every resolved source view (it is optional or missing in at least one source) "
                f"because display.title '{title_prop['name']}' is optional"
            )
    title_swift_expr = (
        f"{title_prop['swift_name']} ?? {fallback_prop['swift_name']}"
        if title_prop['optional']
        else title_prop['swift_name']
    )
    title_expr = f'"\\({title_swift_expr})"'

    subtitle_prop = display_prop('subtitle', required=False)
    if subtitle_prop is None:
        subtitle_expr = 'nil'
    elif subtitle_prop['optional']:
        subtitle_expr = f'{subtitle_prop["swift_name"]}.map {{ "\\($0)" }}'
    else:
        subtitle_expr = f'"\\({subtitle_prop["swift_name"]})"'

    image_prop = display_prop('image', required=False)
    if image_prop is None:
        image_expr = 'nil'
    else:
        if image_prop['swift_type'] != 'URL':
            raise CurationError(f"entity '{name}': display.image must reference a URL-typed property")
        image_expr = (
            f'{image_prop["swift_name"]}.map {{ DisplayRepresentation.Image(url: $0) }}'
            if image_prop['optional']
            else f'DisplayRepresentation.Image(url: {image_prop["swift_name"]})'
        )

    string_query_body = _build_string_query_body(lex_index, name, query_cfg)
    by_ids_body = (
        _build_by_ids_body(lex_index, name, by_ids_cfg)
        if by_ids_cfg
        else _build_fallback_by_ids_body(name)
    )

    swift_sources = []
    for src in sources:
        prop_exprs = {p['swift_name']: p['per_source_expr'][src['qualified']] for p in resolved_props}
        swift_sources.append({
            # Use the resolved-and-qualified "<nsid>#<def>" form, not the verbatim
            # lexicon `raw_ref` — a lexicon-LOCAL ref (bare "#fragment", resolved
            # against its owning lexicon by LexiconIndex.qualify) has no namespace
            # prefix on its own and produces an unqualified (garbage) Swift type
            # name if passed to convert_ref directly.
            'swift_type': convert_ref(src['qualified']),
            'id_expr': id_extract_by_source[src['qualified']],
            'prop_exprs': prop_exprs,
        })

    display_type_name = name[:-len('Entity')] if name.endswith('Entity') else name

    return {
        'name': name,
        'display_type_name': display_type_name,
        'properties': resolved_props,
        'sources': swift_sources,
        'source_refs': [src['qualified'] for src in sources],
        'title_expr': title_expr,
        'subtitle_expr': subtitle_expr,
        'image_expr': image_expr,
        'string_query': True,
        'string_query_body': string_query_body,
        'by_ids_body': by_ids_body,
        'syncable': syncable,
        'indexed': indexed,
    }


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def _gen_header(source_note: str) -> str:
    return f"// GENERATED by app_intents_generator.py — DO NOT EDIT\n// Source: {source_note}"


def render_intent(template_manager: TemplateManager, resolved: dict, availability: str) -> str:
    if resolved['kind'] == 'recordWrite':
        return template_manager.app_record_write_intent_template.render(
            header=_gen_header(resolved['source_nsid']),
            availability=availability,
            struct_name=resolved['struct_name'],
            title=resolved['title'],
            description=resolved['description'],
            confirmation=resolved['confirmation'],
            rw=resolved['record_write'],
        )
    return template_manager.app_intent_template.render(
        header=_gen_header(resolved['source_nsid']),
        availability=availability,
        struct_name=resolved['struct_name'],
        title=resolved['title'],
        description=resolved['description'],
        parameters=resolved['parameters'],
        confirmation=resolved['confirmation'],
        has_input=resolved['has_input'],
        params_expr=resolved['params_expr'],
        returns_type=resolved['returns_type'],
        result_block=resolved['result_block'],
    )


def render_enum(template_manager: TemplateManager, enum_name: str, values: list, source_nsid: str, availability: str) -> str:
    labeled = [(v, (v[0].upper() + v[1:]) if v else v) for v in values]
    return template_manager.app_enum_template.render(
        header=_gen_header(source_nsid),
        availability=availability,
        enum_name=enum_name,
        values=labeled,
    )


def render_entity(template_manager: TemplateManager, resolved: dict, availability: str) -> str:
    return template_manager.app_entity_template.render(
        header=_gen_header(', '.join(resolved['source_refs'])),
        availability=availability,
        name=resolved['name'],
        display_type_name=resolved['display_type_name'],
        properties=resolved['properties'],
        sources=resolved['sources'],
        title_expr=resolved['title_expr'],
        subtitle_expr=resolved['subtitle_expr'],
        image_expr=resolved['image_expr'],
        string_query=resolved['string_query'],
        string_query_body=resolved['string_query_body'],
        by_ids_body=resolved['by_ids_body'],
        syncable=resolved['syncable'],
        indexed=resolved['indexed'],
    )


async def _write_file(path: str, content: str):
    async with aiofiles.open(path, 'w') as f:
        await f.write(content)


class AppIntentsGenerator:
    """Drives app-intents manifest generation end to end: loads the reference
    lexicon set, curates every intent and entity, and writes the resulting
    Swift files under `swift.output`."""

    def __init__(self, manifest: dict, manifest_path: str):
        self.manifest = manifest
        self.manifest_path = manifest_path

    async def generate(self):
        manifest = self.manifest
        manifest_path = self.manifest_path

        _check_known_keys(manifest, _TOP_LEVEL_KEYS, manifest_path)
        _check_known_keys(manifest.get('package') or {}, _PACKAGE_KEYS, f"{manifest_path}: package")

        ai_cfg = manifest.get('appIntents')
        if not ai_cfg:
            raise CurationError(f"{manifest_path}: package.kind 'app-intents' requires an 'appIntents' section")
        _check_known_keys(ai_cfg, _APP_INTENTS_KEYS, f"{manifest_path}: appIntents")
        swift_cfg = manifest.get('swift')
        if not swift_cfg or not swift_cfg.get('output'):
            raise CurationError(f"{manifest_path}: app-intents manifest requires swift.output")
        _check_known_keys(swift_cfg, _SWIFT_KEYS, f"{manifest_path}: swift")
        lex_cfg = manifest.get('lexicons', {})
        _check_known_keys(lex_cfg, _LEXICONS_KEYS, f"{manifest_path}: lexicons")
        reference_dirs_raw = lex_cfg.get('reference', [])
        if not reference_dirs_raw:
            raise CurationError(f"{manifest_path}: app-intents manifest requires lexicons.reference")
        exclude = tuple(lex_cfg.get('exclude_namespaces', DEFAULT_EXCLUDED_NAMESPACES))

        manifest_dir = os.path.dirname(os.path.abspath(manifest_path))
        reference_dirs = [_resolve_path(manifest_dir, d) for d in reference_dirs_raw]
        output_dir = _resolve_path(manifest_dir, swift_cfg['output'])

        availability = ai_cfg.get('availability', 'iOS 18.0')

        lex_index = await load_reference_index(reference_dirs, exclude)

        entities_cfg = ai_cfg.get('entities', [])
        intents_cfg = ai_cfg.get('intents', [])
        if not intents_cfg:
            raise CurationError(f"{manifest_path}: appIntents.intents must declare at least one intent")

        entities_by_name = {}
        for idx, entity_cfg in enumerate(entities_cfg):
            entity_name = entity_cfg.get('name')
            if not entity_name:
                raise CurationError(
                    f"appIntents.entities[{idx}]: every entity needs a 'name' (got: name={entity_name!r})"
                )
            entities_by_name[entity_name] = entity_cfg

        # Pass 1: intents (entity property resolution in pass 2 needs to see every
        # intent's resolved `returns` ref, so intents must resolve first).
        resolved_intents = [
            resolve_intent(lex_index, cfg, entities_by_name, idx) for idx, cfg in enumerate(intents_cfg)
        ]

        # `id` is no longer unique across intents (a recordWrite create/delete
        # pair shares one record NSID), so structName carries uniqueness — and
        # it's also the output filename, so a duplicate would silently
        # overwrite a sibling intent's Swift file.
        seen_struct_names = {}
        for resolved in resolved_intents:
            if resolved['struct_name'] in seen_struct_names:
                raise CurationError(
                    f"appIntents.intents: duplicate structName '{resolved['struct_name']}' "
                    f"(used by both '{seen_struct_names[resolved['struct_name']]}' and "
                    f"'{resolved['source_nsid']}')"
                )
            seen_struct_names[resolved['struct_name']] = resolved['source_nsid']

        # Pass 2: entities.
        resolved_entities = {}
        for idx, entity_cfg in enumerate(entities_cfg):
            resolved_entities[entity_cfg['name']] = resolve_entity(lex_index, entity_cfg, resolved_intents, idx)

        template_manager = TemplateManager()

        intents_dir = os.path.join(output_dir, 'Intents')
        entities_dir = os.path.join(output_dir, 'Entities')
        enums_dir = os.path.join(output_dir, 'Enums')
        for d in (intents_dir, entities_dir, enums_dir):
            os.makedirs(d, exist_ok=True)

        written_enum_names = {}  # insertion-ordered set (dict), see module docstring
        for resolved in resolved_intents:
            code = render_intent(template_manager, resolved, availability)
            await _write_file(os.path.join(intents_dir, f"{resolved['struct_name']}.swift"), code)
            for enum_name, values in resolved['enums']:
                if enum_name in written_enum_names:
                    continue
                written_enum_names[enum_name] = True
                enum_code = render_enum(template_manager, enum_name, values, resolved['source_nsid'], availability)
                await _write_file(os.path.join(enums_dir, f"{enum_name}.swift"), enum_code)

        for entity_name, resolved in resolved_entities.items():
            code = render_entity(template_manager, resolved, availability)
            await _write_file(os.path.join(entities_dir, f"{entity_name}.swift"), code)
