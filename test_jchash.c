#include "jchash.h"

#define NKey 1000
#define NBucket 8

int test() {
    int count[NBucket] = {0};
    int32_t k;
    for (uint64_t i = 1; i <= NKey; i++) {
        k = jump_consistent_hash(i, NBucket);
        /*printf("jchash key=%" PRIu64 ", hash=%" PRId32 "\n", i, k);*/
        count[k]++;
    }
    for (int i = 0; i< NBucket; i++) {
        printf("%d = %d\n", i+1, count[i]);
    }
    return 0;
}

int main(int argc, char *argv[]) {
    test();
    return 0;
}
