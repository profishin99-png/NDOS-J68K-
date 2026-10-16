#ifndef NDOS_BLOCK_H
#define NDOS_BLOCK_H

#include "../fat12/fat12.h"
#include "../include/syscall.h"

typedef struct ndos_ramdisk_context {
    volatile uint8_t *base;
    uint32_t sector_count;
    uint16_t sector_size;
} ndos_ramdisk_context;

/* Temporary MAME-only raw-image SD block adapter. This is not a hardware ABI. */
typedef struct ndos_sdcard_context {
    volatile uint32_t *registers;
    volatile uint8_t *sector_buffer;
    uint32_t sector_count;
} ndos_sdcard_context;

typedef union ndos_default_storage_context {
    ndos_ramdisk_context ramdisk;
    ndos_sdcard_context sdcard;
} ndos_default_storage_context;

void ndos_ramdisk_init(
    fat12_block_device *device,
    ndos_ramdisk_context *context,
    volatile uint8_t *base,
    uint32_t sector_count,
    uint16_t sector_size
);

fat12_status ndos_ramdisk_read_sector(
    void *user_context,
    uint32_t sector,
    uint8_t *destination
);

fat12_status ndos_ramdisk_write_sector(
    void *user_context,
    uint32_t sector,
    const uint8_t *source
);

fat12_status ndos_sdcard_read_sector(
    void *user_context,
    uint32_t sector,
    uint8_t *destination
);

fat12_status ndos_sdcard_write_sector(
    void *user_context,
    uint32_t sector,
    const uint8_t *source
);

int32_t ndos_test_ramdisk_adapter(void);

int32_t ndos_format_ramdisk(void);

int32_t ndos_format_sdcard(void);

int32_t ndos_mount_ramdisk(void);

/* Returns 1 for a valid SD FAT12 volume, 0 for the RAM-disk fallback. */
int32_t ndos_mount_current_volume(void);

int32_t ndos_dir_get(uint32_t visible_index);

int32_t ndos_get_directory_entry(
    uint32_t visible_index,
    ndos_directory_entry *destination
);

int32_t ndos_read_file(
    const char *name,
    uint8_t *destination,
    uint32_t destination_capacity,
    uint32_t *bytes_read
);

int32_t ndos_test_file_read(void);

int32_t ndos_create_file(
    const char *name,
    const uint8_t *source,
    uint32_t size
);

int32_t ndos_delete_file(const char *name);

int32_t ndos_set_file_attributes(const char *name, uint8_t attributes);

int32_t ndos_test_file_create(void);

int32_t ndos_get_disk_free(
    uint32_t *free_clusters,
    uint32_t *free_bytes
);

#endif /* NDOS_BLOCK_H */
