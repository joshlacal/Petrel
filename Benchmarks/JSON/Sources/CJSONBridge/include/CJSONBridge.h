#ifndef PETREL_JSON_BRIDGE_H
#define PETREL_JSON_BRIDGE_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// Non-owning 16-byte DOM/iterator handle. Valid only while its parser lives.
typedef struct { uint64_t a; uint64_t b; } sj_value;
typedef struct sj_document sj_document;
sj_document *sj_parse(const void *data, size_t length, sj_value *root, int *error);
void sj_destroy(sj_document *document);
const char *sj_error(int error);
const char *sj_backend(void);
const char *sj_version(void);
int sj_type(sj_value value);
int sj_bool(sj_value value, int *output);
int sj_int64(sj_value value, int64_t *output);
int sj_uint64(sj_value value, uint64_t *output);
int sj_double(sj_value value, double *output);
int sj_string(sj_value value, const char **output, size_t *length);
int sj_object_get(sj_value object, const char *key, size_t length, sj_value *output);
int sj_object_begin(sj_value object, sj_value *cursor, sj_value *end, size_t *count);
int sj_object_next(sj_value *cursor, sj_value end, const char **key, size_t *length, sj_value *value);
int sj_array_begin(sj_value array, sj_value *cursor, sj_value *end, size_t *count);
int sj_array_next(sj_value *cursor, sj_value end, sj_value *value);
#ifdef __cplusplus
}
#endif
#endif
