def convert_to_camel_case(name: str) -> str:
    """Converts a string to CamelCase."""
    return ''.join(part[0].upper() + part[1:] for part in name.split('.'))

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
            pre_hash_parts = parts[0].split('.')
            camel_case_pre_hash = ''.join([convert_to_camel_case(part) for part in pre_hash_parts])
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
