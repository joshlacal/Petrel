import re

_NON_IDENTIFIER = re.compile(r'[^A-Za-z0-9_]+')


def convert_to_camel_case(name: str) -> str:
    """Converts an NSID, NSID segment or definition name to an UpperCamelCase Swift type name.

    Every character that cannot appear in a Swift identifier starts a new word, so
    `com.my-site.feed.getPost` becomes `ComMySiteFeedGetPost`. NSID authority segments
    may contain hyphens and may start with a digit; a leading digit gets a `_` prefix.
    """
    camel = ''.join(part[0].upper() + part[1:] for part in _NON_IDENTIFIER.split(name) if part)
    if not camel:
        return '_'
    return f'_{camel}' if camel[0].isdigit() else camel


def swift_member_name(name: str) -> str:
    """Wire name (property, parameter, namespace segment) -> lowerCamelCase Swift identifier.

    Names that are already valid identifiers come back unchanged, so `createdAt`,
    `snake_case` and `URL` keep their spelling. Keyword escaping is separate
    (templates.sanitize_swift_keyword), because the bare form is also needed.
    """
    parts = [part for part in _NON_IDENTIFIER.split(name) if part]
    if not parts:
        return '_'
    bare = parts[0] + ''.join(part[0].upper() + part[1:] for part in parts[1:])
    return f'_{bare}' if bare[0].isdigit() else bare


# `Type` and `Protocol` are metatype members and `Self`/`Any` are keywords, so none
# of them can name a nested namespace struct.
_RESERVED_TYPE_NAMES = frozenset({'Type', 'Protocol', 'Self', 'Any'})


def namespace_type_name(segment: str) -> str:
    """NSID namespace segment -> Swift type name of its client namespace struct."""
    name = convert_to_camel_case(segment)
    if name.startswith('_'):
        # A digit-led segment (`4ever`): the accessor property is `_4ever`, and a
        # struct of the same name next to it would make every use ambiguous.
        return f'N{name[1:]}'
    return f'{name}_' if name in _RESERVED_TYPE_NAMES else name


def namespace_type_path(lexicon_id: str) -> str:
    """Dotted Swift path of the namespace struct a lexicon's XRPC method extends.

    All NSID segments but the last, at any depth: `fm.example.alpha.feed.getPlay`
    extends `ATProtoClient.Fm.Example.Alpha.Feed`.
    """
    return '.'.join(namespace_type_name(part) for part in lexicon_id.split('.')[:-1])


def normalize_ref(ref: str, lexicon_id: str) -> str:
    """Fully-qualified form of a ref, as it appears in `$type`.

    `#frag` becomes `<lexicon_id>#frag`, and a `#main` fragment is dropped: the
    Lexicon specification says a main definition is referenced, and typed, by the
    bare NSID.
    """
    nsid, separator, fragment = ref.partition('#')
    nsid = nsid or lexicon_id
    if not separator or fragment == 'main':
        return nsid
    return f'{nsid}#{fragment}'

def convert_ref(ref: str) -> str:
    """Converts a reference to Swift format.
    
    Per the Lexicon spec, #main references should be stripped - the main
    definition is referenced by just the NSID without a fragment.
    """
    if '#' in ref:
        parts = ref.split('#')
        if parts[0] == '':
            # Local reference like #post or #main
            fragment = parts[1]
            if fragment == 'main':
                # #main alone shouldn't happen in practice but handle it
                return 'Main'
            return convert_to_camel_case(fragment)
        else:
            # External reference like com.atproto.repo.strongRef#main
            # The whole NSID at once, exactly as the container struct is named.
            camel_case_pre_hash = convert_to_camel_case(parts[0])
            fragment = parts[1]
            if fragment == 'main':
                # Per Lexicon spec, #main should be omitted - use just the base type
                return camel_case_pre_hash
            return camel_case_pre_hash + '.' + convert_to_camel_case(fragment)
    else:
        return convert_to_camel_case(ref)

def lowercase_first_letter(s):
    if not s:
        return s
    return s[0].lower() + s[1:]
