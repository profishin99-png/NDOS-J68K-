#ifndef NDOS_FAT12_INTERNAL_H
#define NDOS_FAT12_INTERNAL_H

#include "fat12.h"

#define FAT12_BPB_BYTES_PER_SECTOR       11u
#define FAT12_BPB_SECTORS_PER_CLUSTER    13u
#define FAT12_BPB_RESERVED_SECTORS       14u
#define FAT12_BPB_FAT_COUNT              16u
#define FAT12_BPB_ROOT_ENTRY_COUNT       17u
#define FAT12_BPB_TOTAL_SECTORS_16       19u
#define FAT12_BPB_MEDIA_DESCRIPTOR       21u
#define FAT12_BPB_SECTORS_PER_FAT        22u
#define FAT12_BPB_SECTORS_PER_TRACK      24u
#define FAT12_BPB_HEAD_COUNT             26u
#define FAT12_BPB_HIDDEN_SECTORS         28u
#define FAT12_BPB_TOTAL_SECTORS_32       32u
#define FAT12_EXTENDED_DRIVE_NUMBER      36u
#define FAT12_EXTENDED_BOOT_SIGNATURE    38u
#define FAT12_EXTENDED_VOLUME_ID         39u
#define FAT12_VOLUME_LABEL               43u
#define FAT12_FILESYSTEM_TYPE            54u
#define FAT12_BOOT_SIGNATURE_LOW         510u
#define FAT12_BOOT_SIGNATURE_HIGH        511u
#define FAT12_DIRECTORY_ENTRY_SIZE       32u
#define FAT12_MAX_CLUSTER_COUNT          4084u

uint16_t fat12_read_le16(const uint8_t *data);
uint32_t fat12_read_le32(const uint8_t *data);

void fat12_write_le16(
    uint8_t *data,
    uint16_t value
);

void fat12_write_le32(
    uint8_t *data,
    uint32_t value
);

uint16_t fat12_get_entry(
    const uint8_t *fat,
    uint16_t cluster
);

void fat12_set_entry(
    uint8_t *fat,
    uint16_t cluster,
    uint16_t value
);

int32_t fat12_test_endian(void);

#endif /* NDOS_FAT12_INTERNAL_H */
