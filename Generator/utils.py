def convert_to_camel_case(name: str) -> str:
    """Converts a string to CamelCase."""
    return ''.join(part[0].upper() + part[1:] for part in name.split('.'))

def convert_ref(ref: str) -> str:
    """Converts a reference to Swift format."""
    if '#' in ref:
        parts = ref.split('#')
        if parts[0] == '':
            return convert_to_camel_case(parts[1])
        else:
            pre_hash_parts = parts[0].split('.')
            camel_case_pre_hash = ''.join([convert_to_camel_case(part) for part in pre_hash_parts])
            return camel_case_pre_hash + '.' + convert_to_camel_case(parts[1])
    else:
        return convert_to_camel_case(ref)

def lowercase_first_letter(s):
    if not s:
        return s
    return s[0].lower() + s[1:]
