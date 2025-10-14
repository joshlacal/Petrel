#include "shim.h"
#include <libsecret/secret.h>
#include <string.h>
#include <stdlib.h>

bool secret_store_password_simple(
    const char* schema_name,
    const char* attribute_key,
    const char* attribute_value,
    const char* label,
    const char* password,
    size_t password_len,
    char** error_message
) {
    GError *error = NULL;
    
    // Create schema
    SecretSchema schema = {
        .name = schema_name,
        .flags = SECRET_SCHEMA_NONE,
        .attributes = {
            { attribute_key, SECRET_SCHEMA_ATTRIBUTE_STRING },
            { NULL, 0 }
        }
    };
    
    // Use the binary variant to store arbitrary data
    gboolean result = secret_password_store_binary_sync(
        &schema,
        SECRET_COLLECTION_DEFAULT,
        label,
        (const guchar*)password,
        password_len,
        NULL,  // cancellable
        &error,
        attribute_key, attribute_value,
        NULL
    );
    
    if (error) {
        if (error_message) {
            *error_message = strdup(error->message);
        }
        g_error_free(error);
        return false;
    }
    
    return result;
}

char* secret_lookup_password_simple(
    const char* schema_name,
    const char* attribute_key,
    const char* attribute_value,
    size_t* out_len,
    char** error_message
) {
    GError *error = NULL;
    
    SecretSchema schema = {
        .name = schema_name,
        .flags = SECRET_SCHEMA_NONE,
        .attributes = {
            { attribute_key, SECRET_SCHEMA_ATTRIBUTE_STRING },
            { NULL, 0 }
        }
    };
    
    // Use the binary variant to retrieve arbitrary data
    SecretValue *value = secret_password_lookup_binary_sync(
        &schema,
        NULL,  // cancellable
        &error,
        attribute_key, attribute_value,
        NULL
    );
    
    if (error) {
        if (error_message) {
            *error_message = strdup(error->message);
        }
        g_error_free(error);
        return NULL;
    }
    
    if (!value) {
        // Not found, not an error
        if (out_len) {
            *out_len = 0;
        }
        return NULL;
    }
    
    gsize len;
    const guchar *data = secret_value_get(value, &len);
    char *result = malloc(len);
    if (result) {
        memcpy(result, data, len);
        if (out_len) {
            *out_len = len;
        }
    }
    
    secret_value_unref(value);
    return result;
}

bool secret_clear_password_simple(
    const char* schema_name,
    const char* attribute_key,
    const char* attribute_value,
    char** error_message
) {
    GError *error = NULL;
    
    SecretSchema schema = {
        .name = schema_name,
        .flags = SECRET_SCHEMA_NONE,
        .attributes = {
            { attribute_key, SECRET_SCHEMA_ATTRIBUTE_STRING },
            { NULL, 0 }
        }
    };
    
    gboolean result = secret_password_clear_sync(
        &schema,
        NULL,  // cancellable
        &error,
        attribute_key, attribute_value,
        NULL
    );
    
    if (error) {
        if (error_message) {
            *error_message = strdup(error->message);
        }
        g_error_free(error);
        return false;
    }
    
    return result;
}

bool secret_service_available(void) {
    GError *error = NULL;
    
    // Try to get the default service
    SecretService *service = secret_service_get_sync(
        SECRET_SERVICE_NONE,
        NULL,  // cancellable
        &error
    );
    
    if (error) {
        g_error_free(error);
        return false;
    }
    
    if (service) {
        g_object_unref(service);
        return true;
    }
    
    return false;
}
