#include "CBenchMetrics.h"
#include <sys/resource.h>
#include <string>
#ifdef __APPLE__
#include <malloc/malloc.h>
#include <libproc.h>
#include <unistd.h>
#include <atomic>
typedef void(bench_malloc_logger_t)(uint32_t type, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3, uintptr_t result, uint32_t num_hot_frames_to_skip);
extern "C" bench_malloc_logger_t *malloc_logger;
static std::atomic<uint64_t> g_bench_allocs{0}, g_bench_alloc_bytes{0}, g_bench_frees{0};
/* libmalloc stack_logging flags: 2 = allocate, 4 = deallocate, 8 = has zone (arg1 = zone). */
static void bench_count_malloc(uint32_t type, uintptr_t a1, uintptr_t a2, uintptr_t a3, uintptr_t, uint32_t) {
 if (!(type & 2)) { if (type & 4) g_bench_frees.fetch_add(1, std::memory_order_relaxed); return; }
 g_bench_allocs.fetch_add(1, std::memory_order_relaxed);
 uintptr_t size = (type & 4) ? a3 : ((type & 8) ? a2 : a1); /* realloc logs (zone, old ptr, new size) */
 g_bench_alloc_bytes.fetch_add(size, std::memory_order_relaxed);
}
#endif
#include "../../Vendor/simdutf-swift/simdutf/include/simdutf.h"
uint64_t bench_cpu_ns(void) {
 struct rusage r; getrusage(RUSAGE_SELF,&r);
 return ((uint64_t)r.ru_utime.tv_sec+(uint64_t)r.ru_stime.tv_sec)*1000000000ULL+((uint64_t)r.ru_utime.tv_usec+(uint64_t)r.ru_stime.tv_usec)*1000ULL;
}
uint64_t bench_peak_rss(void) { struct rusage r; getrusage(RUSAGE_SELF,&r);
#ifdef __APPLE__
 return r.ru_maxrss;
#else
 return r.ru_maxrss*1024ULL;
#endif
}
uint64_t bench_live_bytes(void) {
#ifdef __APPLE__
 malloc_statistics_t s={0}; malloc_zone_statistics(NULL,&s); return s.size_in_use;
#else
 return 0;
#endif
}
uint64_t bench_live_blocks(void) {
#ifdef __APPLE__
 malloc_statistics_t s={0}; malloc_zone_statistics(NULL,&s); return s.blocks_in_use;
#else
 return 0;
#endif
}
const char *bench_simdutf_backend(void) { static const std::string name(simdutf::get_active_implementation()->name()); return name.c_str(); }

void bench_malloc_counting(int enable) {
#ifdef __APPLE__
 malloc_logger = enable ? bench_count_malloc : nullptr;
#else
 (void)enable;
#endif
}
uint64_t bench_malloc_count(void) {
#ifdef __APPLE__
 return g_bench_allocs.load(std::memory_order_relaxed);
#else
 return 0;
#endif
}
uint64_t bench_malloc_bytes(void) {
#ifdef __APPLE__
 return g_bench_alloc_bytes.load(std::memory_order_relaxed);
#else
 return 0;
#endif
}
uint64_t bench_instructions(void) {
#ifdef __APPLE__
 struct rusage_info_v4 ri;
 if (proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&ri) != 0) return 0;
 return ri.ri_instructions;
#else
 return 0;
#endif
}

// ---- DAG-CBOR lane counters: thin API over the shared malloc_logger hook above ----
void bench_mcount_install(void) { bench_malloc_counting(1); }
void bench_mcount_uninstall(void) { bench_malloc_counting(0); }
void bench_mcount_reset(void) {
#ifdef __APPLE__
 g_bench_allocs.store(0, std::memory_order_relaxed); g_bench_frees.store(0, std::memory_order_relaxed); g_bench_alloc_bytes.store(0, std::memory_order_relaxed);
#endif
}
uint64_t bench_mcount_allocs(void) { return bench_malloc_count(); }
uint64_t bench_mcount_bytes(void) { return bench_malloc_bytes(); }
uint64_t bench_mcount_frees(void) {
#ifdef __APPLE__
 return g_bench_frees.load(std::memory_order_relaxed);
#else
 return 0;
#endif
}
