/*
 * Jump Consistent Hash from Google
 * http://arxiv.org/pdf/1406.2294.pdf
 */
#include "jchash.h"

int32_t jump_consistent_hash(uint64_t key, int32_t num_buckets) {
    int64_t b = -1;
    int64_t j = 0;
    while (j < num_buckets) {
        b = j;
        key = key * 2862933555777941757ULL + 1;
        j = (b + 1) * ((double)(1LL << 31) / (double)((key >> 33) + 1));
    }
    return b;
}
