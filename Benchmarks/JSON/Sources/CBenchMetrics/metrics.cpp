#include "CBenchMetrics.h"
#include <sys/resource.h>
#include <string>
#ifdef __APPLE__
#include <malloc/malloc.h>
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
