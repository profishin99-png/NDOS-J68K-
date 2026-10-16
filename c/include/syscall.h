#ifndef NDOS_SYSCALL_H
#define NDOS_SYSCALL_H

#include <stdint.h>
#include <stddef.h>

/*
 * NDOS application syscall ABI
 *
 * Entry:
 *   TRAP #0
 *   D0.L = zero-extended syscall number
 * 
 * Return:
 *   D0.L = zero or a nonnegative result on success.
 *   D0.L = a negative NDOS error code on failure.
 *
 * Registers D2-D7 and A2-A6 are preserved.
 */

/*
 * Keep the values already used by the current NDOS TRAP #0 dispatcher.
 * Verify these numbers against ndos.s before adding more.
 */

#define NDOS_SYS_INVALID   UINT32_C(0)
#define NDOS_SYS_ADD       UINT32_C(1)
#define NDOS_SYS_SUB       UINT32_C(2)
#define NDOS_SYS_VERSION   UINT32_C(3)
#define NDOS_SYS_EXIT      UINT32_C(4)
#define NDOS_SYS_PUTCHAR   UINT32_C(5)
#define NDOS_SYS_GETCHAR   UINT32_C(6)
#define NDOS_SYS_PUTS      UINT32_C(7)
#define NDOS_SYS_DISK_INFO UINT32_C(8)
#define NDOS_SYS_READ_FILE UINT32_C(9)
#define NDOS_SYS_READ_DIR  UINT32_C(10)
#define NDOS_SYS_CREATE_FILE UINT32_C(11)
#define NDOS_SYS_READ_LINE UINT32_C(12)
#define NDOS_SYS_DELETE_FILE UINT32_C(13)
#define NDOS_SYS_GET_TICKS UINT32_C(14)
#define NDOS_SYS_FORMAT_U32 UINT32_C(15) /* D1.L value, A1 char[11]; return length */
#define NDOS_SYS_FADD_S UINT32_C(16) /* D1.L + D2.L IEEE-754 binary32 -> D0.L */
#define NDOS_SYS_FSUB_S UINT32_C(17) /* D1.L - D2.L IEEE-754 binary32 -> D0.L */
#define NDOS_SYS_SET_ATTRIBUTES UINT32_C(18)
#define NDOS_SYS_READ_LARGE UINT32_C(19) /* Experimental MAME-only large loader. */
#define NDOS_SYS_POLLCHAR UINT32_C(20) /* D0=1/D1.B=byte, or D0=0 if empty */

#define NDOS_OK UINT32_C(0)
#define NDOS_ERR_ARGUMENT (-1)
#define NDOS_ERR_IO (-2)
#define NDOS_ERR_INVALID_FILESYSTEM (-3)
#define NDOS_ERR_UNSUPPORTED (-4)
#define NDOS_ERR_NOT_FOUND (-5)
#define NDOS_ERR_ALREADY_EXISTS (-6)
#define NDOS_ERR_NO_SPACE (-7)
#define NDOS_ERR_DIRECTORY_FULL (-8)
#define NDOS_ERR_INVALID_NAME (-9)
#define NDOS_ERR_CORRUPT_CHAIN (-10)
#define NDOS_ERR_BUFFER_TOO_SMALL (-11)
#define NDOS_ERR_ACCESS_DENIED (-12)

/* FAT12-compatible directory attribute bits returned by NDOS_SYS_READ_DIR. */
#define NDOS_ATTR_READ_ONLY    UINT8_C(0x01)
#define NDOS_ATTR_HIDDEN       UINT8_C(0x02)
#define NDOS_ATTR_SYSTEM       UINT8_C(0x04)
#define NDOS_ATTR_VOLUME_LABEL UINT8_C(0x08)
#define NDOS_ATTR_DIRECTORY    UINT8_C(0x10)
#define NDOS_ATTR_ARCHIVE      UINT8_C(0x20)



/*
 * Returned by NDOS_SYS_DISK_INFO.
 *
 * Values are native MC68020 big-endian integers. Programs do not access
 * FAT12 sectors or little-endian fields directly.
 */
typedef struct ndos_disk_info {
    uint32_t total_bytes;       /* Usable data-cluster bytes. */
    uint32_t free_bytes;
    uint32_t total_clusters;
    uint32_t free_clusters;
    uint32_t bytes_per_cluster;
} ndos_disk_info;

/*
 * One decoded FAT12 root-directory entry returned by NDOS_SYS_READ_DIR.
 * The structure contains native-endian MC68020 integers and deliberately
 * hides the raw FAT directory layout from applications.
 */
typedef struct ndos_directory_entry {
    char name[13];              /* Zero-terminated canonical 8.3 name. */
    uint8_t attributes;
    uint16_t first_cluster;
    uint32_t size;
    uint32_t reserved;
} ndos_directory_entry;

_Static_assert(sizeof(ndos_directory_entry) == 24,
               "NDOS directory entry ABI must remain 24 bytes");

typedef struct ndos_line_buffer {
    uint16_t capacity;
    uint16_t length;
    char data[];
} ndos_line_buffer;

_Static_assert(offsetof(ndos_line_buffer, data) == 4,
               "NDOS line-buffer header must remain four bytes");

#endif
