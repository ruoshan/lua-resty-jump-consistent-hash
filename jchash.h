/*
 * Jump Consistent Hash from Google
 * http://arxiv.org/pdf/1406.2294.pdf
 */
#pragma once

#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>

int32_t jump_consistent_hash(uint64_t key, int32_t num_buckets);
