#include <stdint.h>
#include "fat12/fat12_internal.h"
#include "platform/ndos_block.h"

/*
 * Freestanding C integration probe.  FAT12 will use this same compilation
 * path later; this file deliberately has no NDOS, MAME, or hardware globals.
 */
__attribute__((section(".text.ndos_c_selftest"), used))
int32_t ndos_c_selftest(void)
{
    volatile uint8_t bytes[4];

    bytes[0] = 0x12;
    bytes[1] = 0x34;
    bytes[2] = 0x56;
    bytes[3] = 0x78;

    const uint16_t le16 = (uint16_t)bytes[0]
                        | ((uint16_t)bytes[1] << 8);
    const uint32_t le32 = (uint32_t)bytes[0]
                        | ((uint32_t)bytes[1] << 8)
                        | ((uint32_t)bytes[2] << 16)
                        | ((uint32_t)bytes[3] << 24);

    if (le16 != UINT16_C(0x3412))
        return -1;
    if (le32 != UINT32_C(0x78563412))
        return -2;

    {
        const int32_t fat12_result = fat12_test_endian();
        if (fat12_result != 0)
            return fat12_result;
    }

    return ndos_test_ramdisk_adapter();
}
