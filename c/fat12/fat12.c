#include "fat12_internal.h"


uint16_t fat12_read_le16(const uint8_t *data)
{
   uint16_t low;
    uint16_t high;
    
     low = (uint16_t)data[0];
     high = (uint16_t)data[1]<< 8;
    
     return low | high;
}

uint32_t fat12_read_le32(const uint8_t *data)
{
    uint32_t b0 = (uint32_t)data[0];
    uint32_t b1 = (uint32_t)data[1] << 8;
    uint32_t b2 = (uint32_t)data[2] << 16;
    uint32_t b3 = (uint32_t)data[3] << 24;

    return b0 | b1 | b2 | b3;
}

void fat12_write_le16(  uint8_t *data,
    uint16_t value
)

/*
 * Write a 16-bit value in FAT little-endian byte order.
 */
{
    data[0] = (uint8_t)(value & 0xFF);
    data[1] = (uint8_t)((value >> 8) & 0xFF);
   
} 

void fat12_write_le32(
    uint8_t *data,
    uint32_t value
)
{
    data[0] = (uint8_t)(value & 0xFF);
    data[1] = (uint8_t)((value >> 8) & 0xFF);
    data[2] = (uint8_t)((value >> 16) & 0xFF);
    data[3] = (uint8_t)((value >> 24) & 0xFF);
}

uint16_t fat12_get_entry(
    const uint8_t *fat,
    uint16_t cluster
)
{
    uint32_t offset;
    uint16_t value;

    offset = (uint32_t)cluster + ((uint32_t)cluster >> 1);

    if ((cluster & UINT16_C(1)) == 0) {
        value = (uint16_t)fat[offset]
              | ((uint16_t)(fat[offset + 1] & UINT8_C(0x0F)) << 8);
    } else {
        value = ((uint16_t)fat[offset] >> 4)
              | ((uint16_t)fat[offset + 1] << 4);
    }

    return value & UINT16_C(0x0FFF);
}

void fat12_set_entry(
    uint8_t *fat,
    uint16_t cluster,
    uint16_t value
)
{
    uint32_t offset;

    offset = (uint32_t)cluster
           + ((uint32_t)cluster >> 1);

    value &= UINT16_C(0x0FFF);

    if ((cluster & UINT16_C(1)) == 0) {
        fat[offset] =
            (uint8_t)(value & UINT16_C(0x00FF));

        fat[offset + 1] =
            (uint8_t)(
                (fat[offset + 1] & UINT8_C(0xF0))
                | ((value >> 8) & UINT16_C(0x000F))
            );
    } else {
        fat[offset] =
            (uint8_t)(
                (fat[offset] & UINT8_C(0x0F))
                | ((value << 4) & UINT16_C(0x00F0))
            );

        fat[offset + 1] =
            (uint8_t)((value >> 4) & UINT16_C(0x00FF));
    }
}

fat12_status fat12_mount(
    fat12_filesystem *filesystem,
    const fat12_block_device *device,
    uint8_t *sector_buffer
)
{
    uint32_t total_sectors;
    uint32_t root_directory_bytes;
    uint32_t root_directory_sectors;
    uint32_t fat_start_sector;
    uint32_t root_start_sector;
    uint32_t data_start_sector;
    uint32_t data_sectors;
    uint32_t cluster_count;
    uint32_t fat_entry_capacity;
    uint32_t index;
    uint16_t bytes_per_sector;
    uint16_t reserved_sectors;
    uint16_t root_entry_count;
    uint16_t sectors_per_fat;
    uint8_t sectors_per_cluster;
    uint8_t fat_count;
    uint8_t media_descriptor;

    if (filesystem == NULL || device == NULL || sector_buffer == NULL)
        return FAT12_ERR_ARGUMENT;
    if (device->read_sector == NULL || device->sector_count == 0
        || device->sector_size == 0)
        return FAT12_ERR_ARGUMENT;
    if (device->sector_size != UINT16_C(512))
        return FAT12_ERR_UNSUPPORTED;
    if (device->read_sector(device->user_context, UINT32_C(0), sector_buffer)
        != FAT12_OK)
        return FAT12_ERR_IO;
    if (sector_buffer[FAT12_BOOT_SIGNATURE_LOW] != UINT8_C(0x55)
        || sector_buffer[FAT12_BOOT_SIGNATURE_HIGH] != UINT8_C(0xAA))
        return FAT12_ERR_INVALID_FILESYSTEM;

    bytes_per_sector = fat12_read_le16(
        &sector_buffer[FAT12_BPB_BYTES_PER_SECTOR]);
    sectors_per_cluster = sector_buffer[FAT12_BPB_SECTORS_PER_CLUSTER];
    reserved_sectors = fat12_read_le16(
        &sector_buffer[FAT12_BPB_RESERVED_SECTORS]);
    fat_count = sector_buffer[FAT12_BPB_FAT_COUNT];
    root_entry_count = fat12_read_le16(
        &sector_buffer[FAT12_BPB_ROOT_ENTRY_COUNT]);
    media_descriptor = sector_buffer[FAT12_BPB_MEDIA_DESCRIPTOR];
    sectors_per_fat = fat12_read_le16(
        &sector_buffer[FAT12_BPB_SECTORS_PER_FAT]);
    total_sectors = fat12_read_le16(
        &sector_buffer[FAT12_BPB_TOTAL_SECTORS_16]);
    if (total_sectors == 0)
        total_sectors = fat12_read_le32(
            &sector_buffer[FAT12_BPB_TOTAL_SECTORS_32]);

    if (bytes_per_sector == 0 || sectors_per_cluster == 0
        || reserved_sectors == 0 || fat_count == 0
        || root_entry_count == 0 || sectors_per_fat == 0
        || total_sectors == 0)
        return FAT12_ERR_INVALID_FILESYSTEM;
    if (bytes_per_sector != device->sector_size)
        return FAT12_ERR_UNSUPPORTED;
    if (total_sectors > device->sector_count)
        return FAT12_ERR_INVALID_FILESYSTEM;
    if ((sectors_per_cluster
         & (uint8_t)(sectors_per_cluster - UINT8_C(1))) != 0)
        return FAT12_ERR_INVALID_FILESYSTEM;

    root_directory_bytes = (uint32_t)root_entry_count
                         * (uint32_t)FAT12_DIRECTORY_ENTRY_SIZE;
    root_directory_sectors =
        (root_directory_bytes + (uint32_t)bytes_per_sector - UINT32_C(1))
        / (uint32_t)bytes_per_sector;
    fat_start_sector = reserved_sectors;
    root_start_sector = (uint32_t)reserved_sectors
                      + ((uint32_t)fat_count * (uint32_t)sectors_per_fat);
    data_start_sector = root_start_sector + root_directory_sectors;
    if (data_start_sector >= total_sectors)
        return FAT12_ERR_INVALID_FILESYSTEM;
    data_sectors = total_sectors - data_start_sector;
    cluster_count = data_sectors / sectors_per_cluster;
    if (cluster_count == 0 || cluster_count > FAT12_MAX_CLUSTER_COUNT)
        return FAT12_ERR_UNSUPPORTED;
    fat_entry_capacity = ((uint32_t)sectors_per_fat
                          * (uint32_t)bytes_per_sector * UINT32_C(2))
                       / UINT32_C(3);
    if (fat_entry_capacity < cluster_count + UINT32_C(2))
        return FAT12_ERR_INVALID_FILESYSTEM;

    filesystem->device.user_context = device->user_context;
    filesystem->device.read_sector = device->read_sector;
    filesystem->device.write_sector = device->write_sector;
    filesystem->device.sector_count = device->sector_count;
    filesystem->device.sector_size = device->sector_size;
    filesystem->total_sectors = total_sectors;
    filesystem->fat_start_sector = fat_start_sector;
    filesystem->root_start_sector = root_start_sector;
    filesystem->data_start_sector = data_start_sector;
    filesystem->cluster_count = cluster_count;
    filesystem->bytes_per_sector = bytes_per_sector;
    filesystem->root_entry_count = root_entry_count;
    filesystem->reserved_sector_count = reserved_sectors;
    filesystem->sectors_per_fat = sectors_per_fat;
    filesystem->sectors_per_cluster = sectors_per_cluster;
    filesystem->fat_count = fat_count;
    filesystem->media_descriptor = media_descriptor;

    for (index = 0; index < UINT32_C(11); ++index) {
        filesystem->volume_label[index] =
            sector_buffer[FAT12_EXTENDED_BOOT_SIGNATURE] == UINT8_C(0x29)
            ? sector_buffer[FAT12_VOLUME_LABEL + index]
            : UINT8_C(' ');
    }
    return FAT12_OK;
}

fat12_status fat12_format(
    const fat12_block_device *device,
    uint8_t *sector_buffer,
    const fat12_format_options *options
)
{
    static const uint8_t oem_name[8] = {
        'N', 'D', 'O', 'S', ' ', ' ', ' ', ' '
    };
    static const uint8_t filesystem_type[8] = {
        'F', 'A', 'T', '1', '2', ' ', ' ', ' '
    };
    uint32_t root_sectors;
    uint32_t data_start;
    uint32_t cluster_count;
    uint32_t fat_capacity;
    uint32_t sector;
    uint32_t index;
    uint16_t sectors_per_fat;
    uint8_t fat_index;

    if (device == NULL || sector_buffer == NULL || options == NULL)
        return FAT12_ERR_ARGUMENT;
    if (device->write_sector == NULL || device->sector_count == 0)
        return FAT12_ERR_ARGUMENT;
    if (device->sector_size != UINT16_C(512)
        || options->bytes_per_sector != UINT16_C(512))
        return FAT12_ERR_UNSUPPORTED;
    if (options->total_sectors == 0
        || options->total_sectors > device->sector_count
        || options->root_entry_count == 0
        || options->sectors_per_cluster == 0
        || options->fat_count == 0)
        return FAT12_ERR_ARGUMENT;
    if ((options->sectors_per_cluster
         & (uint8_t)(options->sectors_per_cluster - UINT8_C(1))) != 0)
        return FAT12_ERR_ARGUMENT;

    root_sectors =
        ((uint32_t)options->root_entry_count * UINT32_C(32)
         + UINT32_C(511)) / UINT32_C(512);
    sectors_per_fat = UINT16_C(1);
    for (;;) {
        data_start = UINT32_C(1)
                   + ((uint32_t)options->fat_count * sectors_per_fat)
                   + root_sectors;
        if (data_start >= options->total_sectors)
            return FAT12_ERR_NO_SPACE;
        cluster_count = (options->total_sectors - data_start)
                      / options->sectors_per_cluster;
        if (cluster_count == 0 || cluster_count > FAT12_MAX_CLUSTER_COUNT)
            return FAT12_ERR_UNSUPPORTED;
        fat_capacity = ((uint32_t)sectors_per_fat * UINT32_C(512)
                        * UINT32_C(2)) / UINT32_C(3);
        if (fat_capacity >= cluster_count + UINT32_C(2))
            break;
        if (sectors_per_fat == UINT16_MAX)
            return FAT12_ERR_NO_SPACE;
        ++sectors_per_fat;
    }

    for (index = 0; index < UINT32_C(512); ++index)
        sector_buffer[index] = UINT8_C(0);
    for (sector = 0; sector < options->total_sectors; ++sector) {
        if (device->write_sector(device->user_context, sector, sector_buffer)
            != FAT12_OK)
            return FAT12_ERR_IO;
    }

    sector_buffer[0] = UINT8_C(0xEB);
    sector_buffer[1] = UINT8_C(0x3C);
    sector_buffer[2] = UINT8_C(0x90);
    for (index = 0; index < UINT32_C(8); ++index)
        sector_buffer[3 + index] = oem_name[index];
    fat12_write_le16(&sector_buffer[FAT12_BPB_BYTES_PER_SECTOR],
                     options->bytes_per_sector);
    sector_buffer[FAT12_BPB_SECTORS_PER_CLUSTER] =
        options->sectors_per_cluster;
    fat12_write_le16(&sector_buffer[FAT12_BPB_RESERVED_SECTORS], UINT16_C(1));
    sector_buffer[FAT12_BPB_FAT_COUNT] = options->fat_count;
    fat12_write_le16(&sector_buffer[FAT12_BPB_ROOT_ENTRY_COUNT],
                     options->root_entry_count);
    if (options->total_sectors <= UINT16_MAX) {
        fat12_write_le16(&sector_buffer[FAT12_BPB_TOTAL_SECTORS_16],
                         (uint16_t)options->total_sectors);
    } else {
        fat12_write_le32(&sector_buffer[FAT12_BPB_TOTAL_SECTORS_32],
                         options->total_sectors);
    }
    sector_buffer[FAT12_BPB_MEDIA_DESCRIPTOR] = options->media_descriptor;
    fat12_write_le16(&sector_buffer[FAT12_BPB_SECTORS_PER_FAT],
                     sectors_per_fat);
    fat12_write_le16(&sector_buffer[FAT12_BPB_SECTORS_PER_TRACK], UINT16_C(1));
    fat12_write_le16(&sector_buffer[FAT12_BPB_HEAD_COUNT], UINT16_C(1));
    fat12_write_le32(&sector_buffer[FAT12_BPB_HIDDEN_SECTORS], UINT32_C(0));
    sector_buffer[FAT12_EXTENDED_DRIVE_NUMBER] = UINT8_C(0x80);
    sector_buffer[FAT12_EXTENDED_BOOT_SIGNATURE] = UINT8_C(0x29);
    fat12_write_le32(&sector_buffer[FAT12_EXTENDED_VOLUME_ID],
                     UINT32_C(0x4A36384B));
    for (index = 0; index < UINT32_C(11); ++index)
        sector_buffer[FAT12_VOLUME_LABEL + index] = options->volume_label[index];
    for (index = 0; index < UINT32_C(8); ++index)
        sector_buffer[FAT12_FILESYSTEM_TYPE + index] = filesystem_type[index];
    sector_buffer[FAT12_BOOT_SIGNATURE_LOW] = UINT8_C(0x55);
    sector_buffer[FAT12_BOOT_SIGNATURE_HIGH] = UINT8_C(0xAA);
    if (device->write_sector(device->user_context, UINT32_C(0), sector_buffer)
        != FAT12_OK)
        return FAT12_ERR_IO;

    for (index = 0; index < UINT32_C(512); ++index)
        sector_buffer[index] = UINT8_C(0);
    sector_buffer[0] = options->media_descriptor;
    sector_buffer[1] = UINT8_C(0xFF);
    sector_buffer[2] = UINT8_C(0xFF);
    for (fat_index = 0; fat_index < options->fat_count; ++fat_index) {
        sector = UINT32_C(1) + ((uint32_t)fat_index * sectors_per_fat);
        if (device->write_sector(device->user_context, sector, sector_buffer)
            != FAT12_OK)
            return FAT12_ERR_IO;
    }
    return FAT12_OK;
}

fat12_status fat12_get_root_entry(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    uint32_t visible_index,
    fat12_directory_entry *entry
)
{
    uint32_t root_sector_count;
    uint32_t sector_index;
    uint32_t entry_offset;
    uint32_t current_index = 0;

    if (filesystem == NULL || sector_buffer == NULL || entry == NULL)
        return FAT12_ERR_ARGUMENT;
    if (filesystem->device.read_sector == NULL
        || filesystem->bytes_per_sector != UINT16_C(512))
        return FAT12_ERR_ARGUMENT;

    root_sector_count =
        ((uint32_t)filesystem->root_entry_count * UINT32_C(32)
         + UINT32_C(511)) / UINT32_C(512);

    for (sector_index = 0; sector_index < root_sector_count; ++sector_index) {
        fat12_status status = filesystem->device.read_sector(
            filesystem->device.user_context,
            filesystem->root_start_sector + sector_index,
            sector_buffer);
        if (status != FAT12_OK)
            return FAT12_ERR_IO;

        for (entry_offset = 0; entry_offset < UINT32_C(512);
             entry_offset += UINT32_C(32)) {
            const uint8_t *raw = &sector_buffer[entry_offset];
            uint8_t attributes;
            uint32_t input_index;
            uint32_t output_index;
            uint32_t extension_end;

            if (raw[0] == UINT8_C(0x00))
                return FAT12_ERR_NOT_FOUND;
            if (raw[0] == UINT8_C(0xE5))
                continue;
            attributes = raw[11];
            if (attributes == FAT12_ATTR_LONG_NAME
                || (attributes & (FAT12_ATTR_VOLUME_LABEL
                                  | FAT12_ATTR_HIDDEN
                                  | FAT12_ATTR_SYSTEM)) != 0)
                continue;
            if (current_index++ != visible_index)
                continue;

            output_index = 0;
            for (input_index = 0; input_index < UINT32_C(8)
                 && raw[input_index] != UINT8_C(' '); ++input_index) {
                entry->short_name[output_index++] =
                    (char)(raw[input_index] == UINT8_C(0x05)
                           ? UINT8_C(0xE5) : raw[input_index]);
            }
            extension_end = UINT32_C(11);
            while (extension_end > UINT32_C(8)
                   && raw[extension_end - 1] == UINT8_C(' '))
                --extension_end;
            if (extension_end > UINT32_C(8)) {
                entry->short_name[output_index++] = '.';
                for (input_index = UINT32_C(8);
                     input_index < extension_end; ++input_index)
                    entry->short_name[output_index++] = (char)raw[input_index];
            }
            entry->short_name[output_index] = '\0';
            entry->attributes = attributes;
            entry->first_cluster = fat12_read_le16(&raw[26]);
            entry->size = fat12_read_le32(&raw[28]);
            return FAT12_OK;
        }
    }

    return FAT12_ERR_NOT_FOUND;
}

static uint8_t fat12_ascii_upper(uint8_t value)
{
    if (value >= UINT8_C('a') && value <= UINT8_C('z'))
        return (uint8_t)(value - UINT8_C('a') + UINT8_C('A'));
    return value;
}

static int fat12_valid_short_character(uint8_t value)
{
    if (value < UINT8_C(0x21) || value > UINT8_C(0x7E))
        return 0;
    switch (value) {
    case '"': case '*': case '+': case ',': case '/': case ':': case ';':
    case '<': case '=': case '>': case '?': case '[': case '\\': case ']':
    case '|':
        return 0;
    default:
        return 1;
    }
}

fat12_status fat12_make_short_name(
    const char *name,
    uint8_t short_name[11]
)
{
    uint32_t input_index = 0;
    uint32_t base_length = 0;
    uint32_t extension_length = 0;
    uint32_t index;
    int in_extension = 0;

    if (name == NULL || short_name == NULL || name[0] == '\0')
        return FAT12_ERR_INVALID_NAME;
    for (index = 0; index < UINT32_C(11); ++index)
        short_name[index] = UINT8_C(' ');

    while (name[input_index] != '\0') {
        uint8_t value = (uint8_t)name[input_index++];
        if (value == UINT8_C('.')) {
            if (in_extension || base_length == 0)
                return FAT12_ERR_INVALID_NAME;
            in_extension = 1;
            continue;
        }
        value = fat12_ascii_upper(value);
        if (!fat12_valid_short_character(value))
            return FAT12_ERR_INVALID_NAME;
        if (!in_extension) {
            if (base_length >= UINT32_C(8))
                return FAT12_ERR_INVALID_NAME;
            short_name[base_length++] = value;
        } else {
            if (extension_length >= UINT32_C(3))
                return FAT12_ERR_INVALID_NAME;
            short_name[UINT32_C(8) + extension_length++] = value;
        }
    }
    if (base_length == 0 || (in_extension && extension_length == 0))
        return FAT12_ERR_INVALID_NAME;
    return FAT12_OK;
}

fat12_status fat12_find_root_file(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    const char *name,
    fat12_directory_entry *entry
)
{
    uint8_t wanted[11];
    uint32_t root_sector_count;
    uint32_t sector_index;
    uint32_t entry_offset;
    fat12_status status;

    if (filesystem == NULL || sector_buffer == NULL || entry == NULL)
        return FAT12_ERR_ARGUMENT;
    status = fat12_make_short_name(name, wanted);
    if (status != FAT12_OK)
        return status;
    root_sector_count =
        ((uint32_t)filesystem->root_entry_count * UINT32_C(32)
         + (uint32_t)filesystem->bytes_per_sector - UINT32_C(1))
        / (uint32_t)filesystem->bytes_per_sector;

    for (sector_index = 0; sector_index < root_sector_count; ++sector_index) {
        status = filesystem->device.read_sector(
            filesystem->device.user_context,
            filesystem->root_start_sector + sector_index,
            sector_buffer);
        if (status != FAT12_OK)
            return FAT12_ERR_IO;
        for (entry_offset = 0; entry_offset < filesystem->bytes_per_sector;
             entry_offset += UINT32_C(32)) {
            const uint8_t *raw = &sector_buffer[entry_offset];
            uint32_t index;
            int matches = 1;
            if (raw[0] == UINT8_C(0x00))
                return FAT12_ERR_NOT_FOUND;
            if (raw[0] == UINT8_C(0xE5)
                || raw[11] == FAT12_ATTR_LONG_NAME
                || (raw[11] & (FAT12_ATTR_VOLUME_LABEL
                               | FAT12_ATTR_DIRECTORY)) != 0)
                continue;
            for (index = 0; index < UINT32_C(11); ++index) {
                if (fat12_ascii_upper(raw[index]) != wanted[index]) {
                    matches = 0;
                    break;
                }
            }
            if (!matches)
                continue;
            for (index = 0; index < UINT32_C(8)
                 && wanted[index] != UINT8_C(' '); ++index)
                entry->short_name[index] = (char)wanted[index];
            {
                uint32_t output_index = index;
                if (wanted[8] != UINT8_C(' ')) {
                    entry->short_name[output_index++] = '.';
                    for (index = UINT32_C(8); index < UINT32_C(11)
                         && wanted[index] != UINT8_C(' '); ++index)
                        entry->short_name[output_index++] = (char)wanted[index];
                }
                entry->short_name[output_index] = '\0';
            }
            entry->attributes = raw[11];
            entry->first_cluster = fat12_read_le16(&raw[26]);
            entry->size = fat12_read_le32(&raw[28]);
            return FAT12_OK;
        }
    }
    return FAT12_ERR_NOT_FOUND;
}

static fat12_status fat12_read_chain_entry(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    uint16_t cluster,
    uint16_t *value
)
{
    uint32_t byte_offset = (uint32_t)cluster + ((uint32_t)cluster >> 1);
    uint32_t fat_size = (uint32_t)filesystem->sectors_per_fat
                      * (uint32_t)filesystem->bytes_per_sector;
    uint8_t fat_index;
    uint16_t first_value = 0;

    if (byte_offset + UINT32_C(1) >= fat_size)
        return FAT12_ERR_CORRUPT_CHAIN;
    for (fat_index = 0; fat_index < filesystem->fat_count; ++fat_index) {
        uint32_t fat_base = filesystem->fat_start_sector
            + ((uint32_t)fat_index * filesystem->sectors_per_fat);
        uint32_t sector_offset = byte_offset / filesystem->bytes_per_sector;
        uint32_t within_sector = byte_offset % filesystem->bytes_per_sector;
        uint8_t low;
        uint8_t high;
        uint16_t current;
        if (filesystem->device.read_sector(filesystem->device.user_context,
                fat_base + sector_offset, sector_buffer) != FAT12_OK)
            return FAT12_ERR_IO;
        low = sector_buffer[within_sector];
        if (within_sector + UINT32_C(1) == filesystem->bytes_per_sector) {
            if (filesystem->device.read_sector(filesystem->device.user_context,
                    fat_base + sector_offset + UINT32_C(1), sector_buffer)
                != FAT12_OK)
                return FAT12_ERR_IO;
            high = sector_buffer[0];
        } else {
            high = sector_buffer[within_sector + UINT32_C(1)];
        }
        current = (cluster & UINT16_C(1)) == 0
            ? ((uint16_t)low | ((uint16_t)(high & UINT8_C(0x0F)) << 8))
            : (((uint16_t)low >> 4) | ((uint16_t)high << 4));
        current &= UINT16_C(0x0FFF);
        if (fat_index == 0)
            first_value = current;
        else if (current != first_value)
            return FAT12_ERR_CORRUPT_CHAIN;
    }
    *value = first_value;
    return FAT12_OK;
}

fat12_status fat12_read_file(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    const fat12_directory_entry *entry,
    uint8_t *destination,
    uint32_t destination_capacity,
    uint32_t *bytes_read
)
{
    uint32_t remaining;
    uint32_t output_offset = 0;
    uint32_t visited = 0;
    uint16_t cluster;

    if (bytes_read != NULL)
        *bytes_read = 0;
    if (filesystem == NULL || sector_buffer == NULL || entry == NULL
        || (entry->size != 0 && destination == NULL))
        return FAT12_ERR_ARGUMENT;
    if (destination_capacity < entry->size)
        return FAT12_ERR_BUFFER_TOO_SMALL;
    if (entry->size == 0)
        return entry->first_cluster == 0 ? FAT12_OK : FAT12_ERR_CORRUPT_CHAIN;

    remaining = entry->size;
    cluster = entry->first_cluster;
    while (remaining != 0) {
        uint32_t sector_in_cluster;
        uint16_t next_cluster;
        fat12_status status;
        if (cluster < UINT16_C(2)
            || (uint32_t)cluster >= filesystem->cluster_count + UINT32_C(2)
            || visited++ >= filesystem->cluster_count)
            return FAT12_ERR_CORRUPT_CHAIN;
        for (sector_in_cluster = 0;
             sector_in_cluster < filesystem->sectors_per_cluster
             && remaining != 0; ++sector_in_cluster) {
            uint32_t sector = filesystem->data_start_sector
                + (((uint32_t)cluster - UINT32_C(2))
                   * filesystem->sectors_per_cluster)
                + sector_in_cluster;
            uint32_t count = remaining < filesystem->bytes_per_sector
                ? remaining : filesystem->bytes_per_sector;
            uint32_t index;
            if (filesystem->device.read_sector(filesystem->device.user_context,
                    sector, sector_buffer) != FAT12_OK)
                return FAT12_ERR_IO;
            for (index = 0; index < count; ++index)
                destination[output_offset + index] = sector_buffer[index];
            output_offset += count;
            remaining -= count;
        }
        status = fat12_read_chain_entry(
            filesystem, sector_buffer, cluster, &next_cluster);
        if (status != FAT12_OK)
            return status;
        if (remaining == 0) {
            if (next_cluster < UINT16_C(0x0FF8))
                return FAT12_ERR_CORRUPT_CHAIN;
        } else {
            if (next_cluster < UINT16_C(2)
                || next_cluster >= UINT16_C(0x0FF0))
                return FAT12_ERR_CORRUPT_CHAIN;
            cluster = next_cluster;
        }
    }
    if (bytes_read != NULL)
        *bytes_read = output_offset;
    return FAT12_OK;
}

static fat12_status fat12_write_chain_entry(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    uint16_t cluster,
    uint16_t value
)
{
    uint32_t byte_offset = (uint32_t)cluster + ((uint32_t)cluster >> 1);
    uint32_t fat_size = (uint32_t)filesystem->sectors_per_fat
                      * filesystem->bytes_per_sector;
    uint8_t fat_index;

    value &= UINT16_C(0x0FFF);
    if (filesystem->device.write_sector == NULL
        || byte_offset + UINT32_C(1) >= fat_size)
        return FAT12_ERR_CORRUPT_CHAIN;
    for (fat_index = 0; fat_index < filesystem->fat_count; ++fat_index) {
        uint32_t fat_base = filesystem->fat_start_sector
            + ((uint32_t)fat_index * filesystem->sectors_per_fat);
        uint32_t sector_offset = byte_offset / filesystem->bytes_per_sector;
        uint32_t within_sector = byte_offset % filesystem->bytes_per_sector;
        if (filesystem->device.read_sector(filesystem->device.user_context,
                fat_base + sector_offset, sector_buffer) != FAT12_OK)
            return FAT12_ERR_IO;
        if (within_sector + UINT32_C(1) < filesystem->bytes_per_sector) {
            if ((cluster & UINT16_C(1)) == 0) {
                sector_buffer[within_sector] = (uint8_t)value;
                sector_buffer[within_sector + UINT32_C(1)] =
                    (uint8_t)((sector_buffer[within_sector + UINT32_C(1)]
                               & UINT8_C(0xF0)) | ((value >> 8) & 0x0F));
            } else {
                sector_buffer[within_sector] =
                    (uint8_t)((sector_buffer[within_sector] & UINT8_C(0x0F))
                              | ((value << 4) & 0xF0));
                sector_buffer[within_sector + UINT32_C(1)] =
                    (uint8_t)(value >> 4);
            }
            if (filesystem->device.write_sector(filesystem->device.user_context,
                    fat_base + sector_offset, sector_buffer) != FAT12_OK)
                return FAT12_ERR_IO;
        } else {
            uint8_t first_byte = sector_buffer[within_sector];
            uint8_t second_byte;
            if (filesystem->device.read_sector(filesystem->device.user_context,
                    fat_base + sector_offset + UINT32_C(1), sector_buffer)
                != FAT12_OK)
                return FAT12_ERR_IO;
            second_byte = sector_buffer[0];
            if ((cluster & UINT16_C(1)) == 0) {
                first_byte = (uint8_t)value;
                second_byte = (uint8_t)((second_byte & UINT8_C(0xF0))
                                        | ((value >> 8) & 0x0F));
            } else {
                first_byte = (uint8_t)((first_byte & UINT8_C(0x0F))
                                       | ((value << 4) & 0xF0));
                second_byte = (uint8_t)(value >> 4);
            }
            sector_buffer[0] = second_byte;
            if (filesystem->device.write_sector(filesystem->device.user_context,
                    fat_base + sector_offset + UINT32_C(1), sector_buffer)
                != FAT12_OK)
                return FAT12_ERR_IO;
            if (filesystem->device.read_sector(filesystem->device.user_context,
                    fat_base + sector_offset, sector_buffer) != FAT12_OK)
                return FAT12_ERR_IO;
            sector_buffer[within_sector] = first_byte;
            if (filesystem->device.write_sector(filesystem->device.user_context,
                    fat_base + sector_offset, sector_buffer) != FAT12_OK)
                return FAT12_ERR_IO;
        }
    }
    return FAT12_OK;
}

static fat12_status fat12_find_free_cluster(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    uint16_t *cluster
)
{
    uint32_t candidate;
    for (candidate = UINT32_C(2);
         candidate < filesystem->cluster_count + UINT32_C(2); ++candidate) {
        uint16_t value;
        fat12_status status = fat12_read_chain_entry(
            filesystem, sector_buffer, (uint16_t)candidate, &value);
        if (status != FAT12_OK)
            return status;
        if (value == UINT16_C(0)) {
            *cluster = (uint16_t)candidate;
            return FAT12_OK;
        }
    }
    return FAT12_ERR_NO_SPACE;
}

fat12_status fat12_get_free_space(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    uint32_t *free_clusters,
    uint32_t *free_bytes
)
{
    uint32_t cluster;
    uint32_t count = 0;

    if (filesystem == NULL || sector_buffer == NULL
        || free_clusters == NULL || free_bytes == NULL)
        return FAT12_ERR_ARGUMENT;
    for (cluster = UINT32_C(2);
         cluster < filesystem->cluster_count + UINT32_C(2); ++cluster) {
        uint16_t value;
        fat12_status status = fat12_read_chain_entry(
            filesystem, sector_buffer, (uint16_t)cluster, &value);
        if (status != FAT12_OK)
            return status;
        if (value == UINT16_C(0))
            ++count;
    }
    *free_clusters = count;
    *free_bytes = count * (uint32_t)filesystem->bytes_per_sector
                        * (uint32_t)filesystem->sectors_per_cluster;
    return FAT12_OK;
}

static void fat12_release_chain(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    uint16_t first_cluster
)
{
    uint16_t cluster = first_cluster;
    uint32_t visited = 0;
    while (cluster >= UINT16_C(2)
           && (uint32_t)cluster < filesystem->cluster_count + UINT32_C(2)
           && visited++ < filesystem->cluster_count) {
        uint16_t next;
        if (fat12_read_chain_entry(filesystem, sector_buffer, cluster, &next)
            != FAT12_OK)
            return;
        if (fat12_write_chain_entry(filesystem, sector_buffer, cluster, 0)
            != FAT12_OK)
            return;
        if (next >= UINT16_C(0x0FF8))
            return;
        cluster = next;
    }
}

fat12_status fat12_create_file(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    const char *name,
    const uint8_t *source,
    uint32_t size,
    fat12_directory_entry *created_entry
)
{
    uint8_t short_name[11];
    uint32_t root_sector_count;
    uint32_t directory_sector = 0;
    uint32_t directory_offset = 0;
    uint32_t sector_index;
    uint32_t source_offset = 0;
    uint16_t first_cluster = 0;
    uint16_t previous_cluster = 0;
    int found_slot = 0;
    int reached_end = 0;
    fat12_status status;

    if (filesystem == NULL || sector_buffer == NULL
        || (size != 0 && source == NULL))
        return FAT12_ERR_ARGUMENT;
    if (filesystem->device.write_sector == NULL)
        return FAT12_ERR_UNSUPPORTED;
    status = fat12_make_short_name(name, short_name);
    if (status != FAT12_OK)
        return status;

    root_sector_count =
        ((uint32_t)filesystem->root_entry_count * UINT32_C(32)
         + filesystem->bytes_per_sector - UINT32_C(1))
        / filesystem->bytes_per_sector;
    for (sector_index = 0; sector_index < root_sector_count; ++sector_index) {
        uint32_t offset;
        if (filesystem->device.read_sector(filesystem->device.user_context,
                filesystem->root_start_sector + sector_index, sector_buffer)
            != FAT12_OK)
            return FAT12_ERR_IO;
        for (offset = 0; offset < filesystem->bytes_per_sector;
             offset += UINT32_C(32)) {
            uint8_t *raw = &sector_buffer[offset];
            uint32_t index;
            int matches = 1;
            if (raw[0] == UINT8_C(0x00) || raw[0] == UINT8_C(0xE5)) {
                if (!found_slot) {
                    found_slot = 1;
                    directory_sector = filesystem->root_start_sector
                                     + sector_index;
                    directory_offset = offset;
                }
                if (raw[0] == UINT8_C(0x00))
                {
                    reached_end = 1;
                    break;
                }
                continue;
            }
            if (raw[11] == FAT12_ATTR_LONG_NAME)
                continue;
            for (index = 0; index < UINT32_C(11); ++index) {
                if (fat12_ascii_upper(raw[index]) != short_name[index]) {
                    matches = 0;
                    break;
                }
            }
            if (matches)
                return FAT12_ERR_ALREADY_EXISTS;
        }
        if (reached_end)
            break;
    }
    if (!found_slot)
        return FAT12_ERR_DIRECTORY_FULL;

    while (source_offset < size) {
        uint16_t cluster;
        uint32_t sector_in_cluster;
        status = fat12_find_free_cluster(filesystem, sector_buffer, &cluster);
        if (status != FAT12_OK) {
            fat12_release_chain(filesystem, sector_buffer, first_cluster);
            return status;
        }
        status = fat12_write_chain_entry(
            filesystem, sector_buffer, cluster, UINT16_C(0x0FFF));
        if (status != FAT12_OK) {
            fat12_release_chain(filesystem, sector_buffer, first_cluster);
            return status;
        }
        if (first_cluster == 0)
            first_cluster = cluster;
        if (previous_cluster != 0) {
            status = fat12_write_chain_entry(
                filesystem, sector_buffer, previous_cluster, cluster);
            if (status != FAT12_OK) {
                (void)fat12_write_chain_entry(
                    filesystem, sector_buffer, cluster, 0);
                fat12_release_chain(filesystem, sector_buffer, first_cluster);
                return status;
            }
        }
        previous_cluster = cluster;
        for (sector_in_cluster = 0;
             sector_in_cluster < filesystem->sectors_per_cluster;
             ++sector_in_cluster) {
            uint32_t index;
            uint32_t data_sector = filesystem->data_start_sector
                + (((uint32_t)cluster - UINT32_C(2))
                   * filesystem->sectors_per_cluster)
                + sector_in_cluster;
            for (index = 0; index < filesystem->bytes_per_sector; ++index) {
                sector_buffer[index] = source_offset < size
                    ? source[source_offset++] : UINT8_C(0);
            }
            if (filesystem->device.write_sector(filesystem->device.user_context,
                    data_sector, sector_buffer) != FAT12_OK) {
                fat12_release_chain(filesystem, sector_buffer, first_cluster);
                return FAT12_ERR_IO;
            }
        }
    }

    if (filesystem->device.read_sector(filesystem->device.user_context,
            directory_sector, sector_buffer) != FAT12_OK) {
        fat12_release_chain(filesystem, sector_buffer, first_cluster);
        return FAT12_ERR_IO;
    }
    if (sector_buffer[directory_offset] != UINT8_C(0x00)
        && sector_buffer[directory_offset] != UINT8_C(0xE5)) {
        fat12_release_chain(filesystem, sector_buffer, first_cluster);
        return FAT12_ERR_ALREADY_EXISTS;
    }
    {
        uint8_t *raw = &sector_buffer[directory_offset];
        uint32_t index;
        for (index = 0; index < UINT32_C(32); ++index)
            raw[index] = UINT8_C(0);
        for (index = 0; index < UINT32_C(11); ++index)
            raw[index] = short_name[index];
        raw[11] = FAT12_ATTR_ARCHIVE;
        fat12_write_le16(&raw[26], first_cluster);
        fat12_write_le32(&raw[28], size);
    }
    if (filesystem->device.write_sector(filesystem->device.user_context,
            directory_sector, sector_buffer) != FAT12_OK) {
        fat12_release_chain(filesystem, sector_buffer, first_cluster);
        return FAT12_ERR_IO;
    }
    if (created_entry != NULL) {
        uint32_t index = 0;
        uint32_t input;
        for (input = 0; input < UINT32_C(8)
             && short_name[input] != UINT8_C(' '); ++input)
            created_entry->short_name[index++] = (char)short_name[input];
        if (short_name[8] != UINT8_C(' ')) {
            created_entry->short_name[index++] = '.';
            for (input = UINT32_C(8); input < UINT32_C(11)
                 && short_name[input] != UINT8_C(' '); ++input)
                created_entry->short_name[index++] = (char)short_name[input];
        }
        created_entry->short_name[index] = '\0';
        created_entry->size = size;
        created_entry->first_cluster = first_cluster;
        created_entry->attributes = FAT12_ATTR_ARCHIVE;
    }
    return FAT12_OK;
}

fat12_status fat12_delete_file(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    const char *name
)
{
    uint8_t wanted[11];
    uint32_t root_sector_count;
    uint32_t sector_index;
    fat12_status status;

    if (filesystem == NULL || sector_buffer == NULL || name == NULL)
        return FAT12_ERR_ARGUMENT;
    if (filesystem->device.write_sector == NULL)
        return FAT12_ERR_UNSUPPORTED;
    status = fat12_make_short_name(name, wanted);
    if (status != FAT12_OK)
        return status;
    root_sector_count =
        ((uint32_t)filesystem->root_entry_count * UINT32_C(32)
         + filesystem->bytes_per_sector - UINT32_C(1))
        / filesystem->bytes_per_sector;

    for (sector_index = 0; sector_index < root_sector_count; ++sector_index) {
        uint32_t offset;
        if (filesystem->device.read_sector(filesystem->device.user_context,
                filesystem->root_start_sector + sector_index, sector_buffer)
            != FAT12_OK)
            return FAT12_ERR_IO;
        for (offset = 0; offset < filesystem->bytes_per_sector;
             offset += UINT32_C(32)) {
            uint8_t *raw = &sector_buffer[offset];
            uint32_t index;
            int matches = 1;
            uint16_t first_cluster;
            if (raw[0] == UINT8_C(0x00))
                return FAT12_ERR_NOT_FOUND;
            if (raw[0] == UINT8_C(0xE5)
                || raw[11] == FAT12_ATTR_LONG_NAME
                || (raw[11] & (FAT12_ATTR_VOLUME_LABEL
                               | FAT12_ATTR_DIRECTORY)) != 0)
                continue;
            for (index = 0; index < UINT32_C(11); ++index) {
                if (fat12_ascii_upper(raw[index]) != wanted[index]) {
                    matches = 0;
                    break;
                }
            }
            if (!matches)
                continue;

            if ((raw[11] & (FAT12_ATTR_READ_ONLY
                            | FAT12_ATTR_SYSTEM)) != 0)
                return FAT12_ERR_ACCESS_DENIED;

            first_cluster = fat12_read_le16(&raw[26]);
            if (first_cluster >= UINT16_C(2))
                fat12_release_chain(filesystem, sector_buffer, first_cluster);
            if (filesystem->device.read_sector(filesystem->device.user_context,
                    filesystem->root_start_sector + sector_index,
                    sector_buffer) != FAT12_OK)
                return FAT12_ERR_IO;
            sector_buffer[offset] = UINT8_C(0xE5);
            if (filesystem->device.write_sector(filesystem->device.user_context,
                    filesystem->root_start_sector + sector_index,
                    sector_buffer) != FAT12_OK)
                return FAT12_ERR_IO;
            return FAT12_OK;
        }
    }
    return FAT12_ERR_NOT_FOUND;
}

fat12_status fat12_set_file_attributes(
    fat12_filesystem *filesystem,
    uint8_t *sector_buffer,
    const char *name,
    uint8_t attributes
)
{
    uint8_t wanted[11];
    uint32_t root_sector_count;
    uint32_t sector_index;
    fat12_status status;

    if (filesystem == NULL || sector_buffer == NULL || name == NULL)
        return FAT12_ERR_ARGUMENT;
    if (filesystem->device.write_sector == NULL)
        return FAT12_ERR_UNSUPPORTED;
    if ((attributes & (uint8_t)~(FAT12_ATTR_READ_ONLY
                                 | FAT12_ATTR_HIDDEN
                                 | FAT12_ATTR_SYSTEM
                                 | FAT12_ATTR_ARCHIVE)) != 0)
        return FAT12_ERR_ARGUMENT;

    status = fat12_make_short_name(name, wanted);
    if (status != FAT12_OK)
        return status;
    root_sector_count =
        ((uint32_t)filesystem->root_entry_count * UINT32_C(32)
         + filesystem->bytes_per_sector - UINT32_C(1))
        / filesystem->bytes_per_sector;

    for (sector_index = 0; sector_index < root_sector_count; ++sector_index) {
        uint32_t offset;
        if (filesystem->device.read_sector(filesystem->device.user_context,
                filesystem->root_start_sector + sector_index, sector_buffer)
            != FAT12_OK)
            return FAT12_ERR_IO;
        for (offset = 0; offset < filesystem->bytes_per_sector;
             offset += UINT32_C(32)) {
            uint8_t *raw = &sector_buffer[offset];
            uint32_t index;
            int matches = 1;

            if (raw[0] == UINT8_C(0x00))
                return FAT12_ERR_NOT_FOUND;
            if (raw[0] == UINT8_C(0xE5)
                || raw[11] == FAT12_ATTR_LONG_NAME
                || (raw[11] & (FAT12_ATTR_VOLUME_LABEL
                               | FAT12_ATTR_DIRECTORY)) != 0)
                continue;
            for (index = 0; index < UINT32_C(11); ++index) {
                if (fat12_ascii_upper(raw[index]) != wanted[index]) {
                    matches = 0;
                    break;
                }
            }
            if (!matches)
                continue;

            raw[11] = attributes;
            if (filesystem->device.write_sector(filesystem->device.user_context,
                    filesystem->root_start_sector + sector_index,
                    sector_buffer) != FAT12_OK)
                return FAT12_ERR_IO;
            return FAT12_OK;
        }
    }
    return FAT12_ERR_NOT_FOUND;
}

int32_t fat12_test_endian(void)
{
    uint8_t bytes[6];

    /*
     * Read a known 16-bit little-endian value.
     */
    bytes[0] = UINT8_C(0x34);
    bytes[1] = UINT8_C(0x12);

    if (fat12_read_le16(bytes) != UINT16_C(0x1234))
        return -1;

    /*
     * Write a known 16-bit value.
     */
    bytes[0] = UINT8_C(0x00);
    bytes[1] = UINT8_C(0x00);

    fat12_write_le16(bytes, UINT16_C(0xABCD));

    if (bytes[0] != UINT8_C(0xCD))
        return -2;

    if (bytes[1] != UINT8_C(0xAB))
        return -3;

    /*
     * Confirm a 16-bit write/read round trip.
     */
    if (fat12_read_le16(bytes) != UINT16_C(0xABCD))
        return -4;

    /*
     * Read a known 32-bit little-endian value.
     */
    bytes[0] = UINT8_C(0x78);
    bytes[1] = UINT8_C(0x56);
    bytes[2] = UINT8_C(0x34);
    bytes[3] = UINT8_C(0x12);

    if (fat12_read_le32(bytes) != UINT32_C(0x12345678))
        return -5;

    /*
     * Write a known 32-bit value.
     */
    bytes[0] = UINT8_C(0x00);
    bytes[1] = UINT8_C(0x00);
    bytes[2] = UINT8_C(0x00);
    bytes[3] = UINT8_C(0x00);

    fat12_write_le32(bytes, UINT32_C(0x89ABCDEF));

    if (bytes[0] != UINT8_C(0xEF))
        return -6;

    if (bytes[1] != UINT8_C(0xCD))
        return -7;

    if (bytes[2] != UINT8_C(0xAB))
        return -8;

    if (bytes[3] != UINT8_C(0x89))
        return -9;

    /*
     * Confirm a 32-bit write/read round trip.
     */
    if (fat12_read_le32(bytes) != UINT32_C(0x89ABCDEF))
        return -10;

    /* Cluster 2 is $ABC and cluster 3 is $125 in these packed bytes. */
    bytes[3] = UINT8_C(0xBC);
    bytes[4] = UINT8_C(0x5A);
    bytes[5] = UINT8_C(0x12);

    if (fat12_get_entry(bytes, UINT16_C(2)) != UINT16_C(0x0ABC))
        return -11;

    if (fat12_get_entry(bytes, UINT16_C(3)) != UINT16_C(0x0125))
        return -12;

    fat12_set_entry(bytes, UINT16_C(2), UINT16_C(0x0456));

    if (bytes[3] != UINT8_C(0x56)
        || bytes[4] != UINT8_C(0x54)
        || bytes[5] != UINT8_C(0x12))
        return -13;

    if (fat12_get_entry(bytes, UINT16_C(2)) != UINT16_C(0x0456)
        || fat12_get_entry(bytes, UINT16_C(3)) != UINT16_C(0x0125))
        return -14;

    bytes[3] = UINT8_C(0xBC);
    bytes[4] = UINT8_C(0x5A);
    bytes[5] = UINT8_C(0x12);
    fat12_set_entry(bytes, UINT16_C(3), UINT16_C(0x0789));

    if (bytes[3] != UINT8_C(0xBC)
        || bytes[4] != UINT8_C(0x9A)
        || bytes[5] != UINT8_C(0x78))
        return -15;

    if (fat12_get_entry(bytes, UINT16_C(2)) != UINT16_C(0x0ABC)
        || fat12_get_entry(bytes, UINT16_C(3)) != UINT16_C(0x0789))
        return -16;

    return 0;
}
