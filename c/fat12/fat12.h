
#ifndef NDOS_FAT12_H
#define NDOS_FAT12_H
#include <stddef.h>
#include <stdint.h>

/*
 * FAT12 operation results.
 *
 * FAT12_OK is zero. All errors are nonzero so callers can use:
 *
 *     if (result != FAT12_OK) {
 *         ...
 *     }
 */
typedef enum fat12_status {
    FAT12_OK = 0,

    FAT12_ERR_ARGUMENT = 1,
    FAT12_ERR_IO = 2,
    FAT12_ERR_INVALID_FILESYSTEM = 3,
    FAT12_ERR_UNSUPPORTED = 4,
    FAT12_ERR_NOT_FOUND = 5,
    FAT12_ERR_ALREADY_EXISTS = 6,
    FAT12_ERR_NO_SPACE = 7,
    FAT12_ERR_DIRECTORY_FULL = 8,
    FAT12_ERR_INVALID_NAME = 9,
    FAT12_ERR_CORRUPT_CHAIN = 10,
    FAT12_ERR_BUFFER_TOO_SMALL = 11,
    FAT12_ERR_ACCESS_DENIED = 12,
} fat12_status;

/* FAT12 directory-entry attribute bits (byte 11 of a 32-byte entry). */
#define FAT12_ATTR_READ_ONLY    UINT8_C(0x01)
#define FAT12_ATTR_HIDDEN       UINT8_C(0x02)
#define FAT12_ATTR_SYSTEM       UINT8_C(0x04)
#define FAT12_ATTR_VOLUME_LABEL UINT8_C(0x08)
#define FAT12_ATTR_DIRECTORY    UINT8_C(0x10)
#define FAT12_ATTR_ARCHIVE      UINT8_C(0x20)
#define FAT12_ATTR_LONG_NAME    UINT8_C(0x0F)


/*
 * Block-device callbacks.
 *
 * user_context is supplied by the platform adapter. The portable FAT12
 * implementation must pass it back unchanged.
 *
 * Each operation reads or writes exactly one logical sector.
 */
typedef fat12_status (*fat12_read_sector_fn)(
    void *user_context,
    uint32_t sector,
    uint8_t *destination);

typedef fat12_status (*fat12_write_sector_fn)(
    void *user_context,
    uint32_t sector,
    const uint8_t *source);


/*
 * A block device provided by the caller.
 *
 * FAT12 does not know whether this represents RAM, an SD card, a disk-image
 * file, or another storage device.
 */

 typedef struct fat12_block_device {
    void *user_context;


    fat12_read_sector_fn read_sector;
    fat12_write_sector_fn write_sector;

    uint32_t sector_count;
    uint16_t sector_size;
 } fat12_block_device;

/*
 * Parameters used when creating a new FAT12 volume.
 *
 * volume_label contains exactly 11 FAT characters, padded with spaces.
 * It is not a normal zero-terminated C string.
 */ 

typedef struct fat12_format_options {
   uint32_t total_sectors;

    uint16_t bytes_per_sector;
    uint16_t root_entry_count;

    uint8_t sectors_per_cluster;
    uint8_t fat_count;
    uint8_t media_descriptor;

    uint8_t volume_label[11];
   } fat12_format_options;


    
/*
 * Information about a mounted FAT12 filesystem.
 *
 * These fields are derived from the on-disk BPB during fat12_mount().
 */
typedef struct fat12_filesystem {
    fat12_block_device device;

    uint32_t total_sectors;
    uint32_t fat_start_sector;
    uint32_t root_start_sector;
    uint32_t data_start_sector;
    uint32_t cluster_count;

    uint16_t bytes_per_sector;
    uint16_t root_entry_count;
    uint16_t reserved_sector_count;
    uint16_t sectors_per_fat;

    uint8_t sectors_per_cluster;
    uint8_t fat_count;
    uint8_t media_descriptor;
    uint8_t volume_label[11];

} fat12_filesystem;

typedef struct fat12_directory_entry {
    char short_name[13];
    uint32_t size;
    uint16_t first_cluster;
    uint8_t attributes;
} fat12_directory_entry;


/*
 * Create a FAT12 filesystem on a block device.
 *
 * sector_buffer must contain at least device->sector_size writable bytes.
 */
fat12_status fat12_format(
    const fat12_block_device *device,
    uint8_t *sector_buffer,
    const fat12_format_options *options
);

/*
 * Read, validate and mount an existing FAT12 filesystem.
 *
 * sector_buffer must contain at least device->sector_size writable bytes.
 */

fat12_status fat12_mount(
    fat12_filesystem *filesystem,
    const fat12_block_device *device,
    uint8_t *sector_buffer
);

/*
 * Return one normal visible root entry.  Volume labels, long-name records,
 * hidden entries, and system entries are omitted.  Direct lookup still sees
 * hidden and system files so the kernel can read its own named files.
 */
fat12_status fat12_get_root_entry(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    uint32_t visible_index,
    fat12_directory_entry *entry
);

/* Convert NAME.EXT to the canonical, space-padded 11-byte FAT short name. */
fat12_status fat12_make_short_name(
    const char *name,
    uint8_t short_name[11]
);

/* Locate a regular file in the fixed FAT12 root directory. */
fat12_status fat12_find_root_file(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    const char *name,
    fat12_directory_entry *entry
);

/*
 * Read a complete file by following its FAT12 cluster chain.
 * destination_capacity must be at least entry->size.  bytes_read may be NULL.
 */
fat12_status fat12_read_file(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    const fat12_directory_entry *entry,
    uint8_t *destination,
    uint32_t destination_capacity,
    uint32_t *bytes_read
);

/* Create a new root-directory file and allocate its FAT12 cluster chain. */
fat12_status fat12_create_file(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    const char *name,
    const uint8_t *source,
    uint32_t size,
    fat12_directory_entry *created_entry
);

fat12_status fat12_delete_file(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    const char *name
);

/*
 * Replace the mutable FAT12 attribute bits on a regular root file.
 *
 * Only READ_ONLY, HIDDEN, SYSTEM, and ARCHIVE are accepted.  This function
 * does not create directories or modify volume-label/LFN directory records.
 */
fat12_status fat12_set_file_attributes(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    const char *name,
    uint8_t attributes
);

fat12_status fat12_get_free_space(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    uint32_t *free_clusters,
    uint32_t *free_bytes
);

#endif /* NDOS_FAT12_H */
