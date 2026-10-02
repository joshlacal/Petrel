#ifndef CBENCHMETRICS_H
#define CBENCHMETRICS_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
uint64_t bench_cpu_ns(void);
uint64_t bench_peak_rss(void);
uint64_t bench_live_bytes(void);
uint64_t bench_live_blocks(void);
const char *bench_simdutf_backend(void);
const char *bench_zippy_backend(void);
int bench_zippy_parse(const char *, size_t);
/* Deterministic counters (Darwin only; zero elsewhere). Allocation counting hooks
   libmalloc's malloc_logger, so it observes every zone allocation, realloc counted once. */
void bench_malloc_counting(int enable);
uint64_t bench_malloc_count(void);
uint64_t bench_malloc_bytes(void);
uint64_t bench_instructions(void);
/* DAG-CBOR lane counters: same malloc_logger hook as above (shared counters), plus a free count. */
void bench_mcount_install(void);
void bench_mcount_uninstall(void);
void bench_mcount_reset(void);
uint64_t bench_mcount_allocs(void);
uint64_t bench_mcount_frees(void);
uint64_t bench_mcount_bytes(void);
#ifdef __cplusplus
}
#endif
#endif
