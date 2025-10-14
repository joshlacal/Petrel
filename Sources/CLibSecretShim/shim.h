#ifndef LIBSECRET_SHIM_H
#define LIBSECRET_SHIM_H

#include <stddef.h>
#include <stdbool.h>

/// Store password/data in the keyring
/// @param schema_name Name of the schema (e.g., "org.petrel.credentials")
/// @param attribute_key Attribute key name (e.g., "key")
/// @param attribute_value Attribute key value (e.g., "namespace.keyname")
/// @param label Human-readable label for the item
/// @param password Binary data to store
/// @param password_len Length of the binary data
/// @param error_message Output parameter for error message (must be freed by caller)
/// @return true on success, false on failure
bool secret_store_password_simple(
    const char* schema_name,
    const char* attribute_key,
    const char* attribute_value,
    const char* label,
    const char* password,
    size_t password_len,
    char** error_message
);

/// Lookup password/data from the keyring
/// @param schema_name Name of the schema
/// @param attribute_key Attribute key name
/// @param attribute_value Attribute key value
/// @param out_len Output parameter for data length
/// @param error_message Output parameter for error message (must be freed by caller)
/// @return Pointer to data (must be freed by caller), or NULL if not found/error
char* secret_lookup_password_simple(
    const char* schema_name,
    const char* attribute_key,
    const char* attribute_value,
    size_t* out_len,
    char** error_message
);

/// Clear/delete password/data from the keyring
/// @param schema_name Name of the schema
/// @param attribute_key Attribute key name
/// @param attribute_value Attribute key value
/// @param error_message Output parameter for error message (must be freed by caller)
/// @return true on success, false on failure
bool secret_clear_password_simple(
    const char* schema_name,
    const char* attribute_key,
    const char* attribute_value,
    char** error_message
);

/// Check if libsecret/Secret Service is available
/// @return true if available, false otherwise
bool secret_service_available(void);

#endif
