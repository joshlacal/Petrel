#include "include/CJSONBridge.h"
#define simdjson petrel_bench_simdjson
#include "../../Vendor/simdjson/simdjson.h"
#include <cstring>
#include <new>
#include <type_traits>

struct sj_document { simdjson::dom::parser parser; };
template<class T> static sj_value pack(T value) {
    static_assert(sizeof(T) == sizeof(sj_value), "DOM ABI changed");
    static_assert(std::is_trivially_copyable<T>::value, "DOM handle must be trivially copyable");
    sj_value result; std::memcpy(&result, &value, sizeof(result)); return result;
}
template<class T> static T unpack(sj_value value) {
    static_assert(sizeof(T) == sizeof(sj_value), "DOM ABI changed");
    static_assert(std::is_trivially_copyable<T>::value, "DOM handle must be trivially copyable");
    T result; std::memcpy(&result, &value, sizeof(result)); return result;
}
extern "C" sj_document *sj_parse(const void *data, size_t length, sj_value *root, int *error) {
    auto *document = new (std::nothrow) sj_document;
    if (!document) { *error = int(simdjson::MEMALLOC); return nullptr; }
    simdjson::dom::element result;
    // Data does not guarantee SIMDJSON_PADDING. This overload copies into the
    // parser-owned padded buffer. Include that copy in end-to-end timings.
    auto code = document->parser.parse(static_cast<const uint8_t *>(data), length, true).get(result);
    *error = int(code);
    if (code) { delete document; return nullptr; }
    *root = pack(result); return document;
}
extern "C" void sj_destroy(sj_document *document) { delete document; }
extern "C" const char *sj_error(int error) { return simdjson::error_message(simdjson::error_code(error)); }
extern "C" const char *sj_backend() {
    static const std::string name = simdjson::get_active_implementation()->name();
    return name.c_str();
}
extern "C" const char *sj_version() { return SIMDJSON_VERSION; }
extern "C" int sj_type(sj_value value) { return int(unpack<simdjson::dom::element>(value).type()); }
extern "C" int sj_bool(sj_value value, int *output) { bool result; auto e = unpack<simdjson::dom::element>(value).get_bool().get(result); if (!e) *output = result; return int(e); }
extern "C" int sj_int64(sj_value value, int64_t *output) { return int(unpack<simdjson::dom::element>(value).get_int64().get(*output)); }
extern "C" int sj_uint64(sj_value value, uint64_t *output) { return int(unpack<simdjson::dom::element>(value).get_uint64().get(*output)); }
extern "C" int sj_double(sj_value value, double *output) { return int(unpack<simdjson::dom::element>(value).get_double().get(*output)); }
extern "C" int sj_string(sj_value value, const char **output, size_t *length) {
    std::string_view result; auto e = unpack<simdjson::dom::element>(value).get_string().get(result);
    if (!e) { *output = result.data(); *length = result.size(); } return int(e);
}
extern "C" int sj_object_get(sj_value object, const char *key, size_t length, sj_value *output) {
    simdjson::dom::element result; auto e = unpack<simdjson::dom::element>(object).at_key(std::string_view(key, length)).get(result);
    if (!e) *output = pack(result); return int(e);
}
extern "C" int sj_object_begin(sj_value object, sj_value *cursor, sj_value *end, size_t *count) {
    simdjson::dom::object result; auto e = unpack<simdjson::dom::element>(object).get_object().get(result);
    if (!e) { *cursor = pack(result.begin()); *end = pack(result.end()); *count = result.size(); } return int(e);
}
extern "C" int sj_object_next(sj_value *cursor, sj_value end, const char **key, size_t *length, sj_value *value) {
    auto i = unpack<simdjson::dom::object::iterator>(*cursor);
    if (i == unpack<simdjson::dom::object::iterator>(end)) return 0;
    auto k = i.key(); *key = k.data(); *length = k.size(); *value = pack(i.value()); ++i; *cursor = pack(i); return 1;
}
extern "C" int sj_array_begin(sj_value array, sj_value *cursor, sj_value *end, size_t *count) {
    simdjson::dom::array result; auto e = unpack<simdjson::dom::element>(array).get_array().get(result);
    if (!e) { *cursor = pack(result.begin()); *end = pack(result.end()); *count = result.size(); } return int(e);
}
extern "C" int sj_array_next(sj_value *cursor, sj_value end, sj_value *value) {
    auto i = unpack<simdjson::dom::array::iterator>(*cursor);
    if (i == unpack<simdjson::dom::array::iterator>(end)) return 0;
    *value = pack(*i); ++i; *cursor = pack(i); return 1;
}
