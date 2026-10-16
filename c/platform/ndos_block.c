#include "ndos_block.h"
#include "../fat12/fat12_internal.h"

#define NDOS_RAMDISK_BASE_ADDRESS UINT32_C(0x00100000)
#define NDOS_RAMDISK_SECTOR_COUNT UINT32_C(1024)
#define NDOS_RAMDISK_SECTOR_SIZE  UINT16_C(512)
#define NDOS_SECTOR_BUFFER_ADDRESS UINT32_C(0x00180000)
#define NDOS_MAME_SDCARD_REGISTERS UINT32_C(0x00E30000)
#define NDOS_MAME_SDCARD_BUFFER    UINT32_C(0x00E31000)
#define NDOS_MAME_SDCARD_PRESENT   UINT32_C(0x40000000)
#define NDOS_MAME_SDCARD_COMMAND  UINT32_C(0x04)
#define NDOS_MAME_SDCARD_LBA      UINT32_C(0x08)
#define NDOS_MAME_SDCARD_COUNT    UINT32_C(0x0C)
#define NDOS_MAME_SDCARD_READ     UINT32_C(1)
#define NDOS_MAME_SDCARD_WRITE    UINT32_C(2)
#define NDOS_MAME_SDCARD_ERROR_MASK UINT32_C(0xFF)

static void ndos_init_default_ramdisk(
    fat12_block_device *device,
    ndos_ramdisk_context *context
)
{
    ndos_ramdisk_init(
        device,
        context,
        (volatile uint8_t *)(uintptr_t)NDOS_RAMDISK_BASE_ADDRESS,
        NDOS_RAMDISK_SECTOR_COUNT,
        NDOS_RAMDISK_SECTOR_SIZE
    );
}

static void ndos_init_default_device(
    fat12_block_device *device,
    ndos_default_storage_context *context
)
{
    volatile uint32_t *registers = (volatile uint32_t *)(uintptr_t)
        NDOS_MAME_SDCARD_REGISTERS;
    uint32_t status = registers[0];
    uint32_t sector_count;

    if ((status & NDOS_MAME_SDCARD_PRESENT) != 0) {
        sector_count = registers[NDOS_MAME_SDCARD_COUNT / 4];
        if (sector_count != 0) {
            context->sdcard.registers = registers;
            context->sdcard.sector_buffer = (volatile uint8_t *)(uintptr_t)
                NDOS_MAME_SDCARD_BUFFER;
            context->sdcard.sector_count = sector_count;
            device->user_context = &context->sdcard;
            device->read_sector = ndos_sdcard_read_sector;
            device->write_sector = ndos_sdcard_write_sector;
            device->sector_count = sector_count;
            device->sector_size = NDOS_RAMDISK_SECTOR_SIZE;
            return;
        }
    }

    ndos_ramdisk_init(
        device,
        &context->ramdisk,
        (volatile uint8_t *)(uintptr_t)NDOS_RAMDISK_BASE_ADDRESS,
        NDOS_RAMDISK_SECTOR_COUNT,
        NDOS_RAMDISK_SECTOR_SIZE
    );
}

void ndos_ramdisk_init(
    fat12_block_device *device,
    ndos_ramdisk_context *context,
    volatile uint8_t *base,
    uint32_t sector_count,
    uint16_t sector_size
)
{
    context->base = base;
    context->sector_count = sector_count;
    context->sector_size = sector_size;

    device->user_context = context;
    device->read_sector = ndos_ramdisk_read_sector;
    device->write_sector = ndos_ramdisk_write_sector;
    device->sector_count = sector_count;
    device->sector_size = sector_size;
}

fat12_status ndos_ramdisk_read_sector(
    void *user_context,
    uint32_t sector,
    uint8_t *destination
)
{
    ndos_ramdisk_context *context;
    volatile const uint8_t *source;
    uint32_t index;

    if (user_context == NULL || destination == NULL)
        return FAT12_ERR_ARGUMENT;

    context = (ndos_ramdisk_context *)user_context;
    if (context->base == NULL || context->sector_size == 0
        || sector >= context->sector_count)
        return FAT12_ERR_ARGUMENT;

    source = context->base + (sector * (uint32_t)context->sector_size);
    for (index = 0; index < context->sector_size; ++index)
        destination[index] = source[index];

    return FAT12_OK;
}

fat12_status ndos_ramdisk_write_sector(
    void *user_context,
    uint32_t sector,
    const uint8_t *source
)
{
    ndos_ramdisk_context *context;
    volatile uint8_t *destination;
    uint32_t index;

    if (user_context == NULL || source == NULL)
        return FAT12_ERR_ARGUMENT;

    context = (ndos_ramdisk_context *)user_context;
    if (context->base == NULL || context->sector_size == 0
        || sector >= context->sector_count)
        return FAT12_ERR_ARGUMENT;

    destination = context->base + (sector * (uint32_t)context->sector_size);
    for (index = 0; index < context->sector_size; ++index)
        destination[index] = source[index];

    return FAT12_OK;
}

fat12_status ndos_sdcard_read_sector(
    void *user_context,
    uint32_t sector,
    uint8_t *destination
)
{
    ndos_sdcard_context *context = (ndos_sdcard_context *)user_context;
    uint32_t index;

    if (context == NULL || destination == NULL || context->registers == NULL
        || context->sector_buffer == NULL || sector >= context->sector_count)
        return FAT12_ERR_ARGUMENT;
    if ((context->registers[0] & NDOS_MAME_SDCARD_PRESENT) == 0)
        return FAT12_ERR_IO;

    context->registers[NDOS_MAME_SDCARD_LBA / 4] = sector;
    context->registers[NDOS_MAME_SDCARD_COMMAND / 4] = NDOS_MAME_SDCARD_READ;
    if ((context->registers[0] & NDOS_MAME_SDCARD_ERROR_MASK) != 0)
        return FAT12_ERR_IO;
    for (index = 0; index < NDOS_RAMDISK_SECTOR_SIZE; ++index)
        destination[index] = context->sector_buffer[index];
    return FAT12_OK;
}

fat12_status ndos_sdcard_write_sector(
    void *user_context,
    uint32_t sector,
    const uint8_t *source
)
{
    ndos_sdcard_context *context = (ndos_sdcard_context *)user_context;
    uint32_t index;

    if (context == NULL || source == NULL || context->registers == NULL
        || context->sector_buffer == NULL || sector >= context->sector_count)
        return FAT12_ERR_ARGUMENT;
    if ((context->registers[0] & NDOS_MAME_SDCARD_PRESENT) == 0)
        return FAT12_ERR_IO;

    for (index = 0; index < NDOS_RAMDISK_SECTOR_SIZE; ++index)
        context->sector_buffer[index] = source[index];
    context->registers[NDOS_MAME_SDCARD_LBA / 4] = sector;
    context->registers[NDOS_MAME_SDCARD_COMMAND / 4] = NDOS_MAME_SDCARD_WRITE;
    if ((context->registers[0] & NDOS_MAME_SDCARD_ERROR_MASK) != 0)
        return FAT12_ERR_IO;
    return FAT12_OK;
}

int32_t ndos_test_ramdisk_adapter(void)
{
    fat12_block_device device;
    fat12_filesystem filesystem;
    ndos_ramdisk_context context;
    uint8_t saved[512];
    uint8_t test[512];
    uint32_t index;
    const uint32_t sector = UINT32_C(1023);

    ndos_ramdisk_init(
        &device,
        &context,
        (volatile uint8_t *)(uintptr_t)NDOS_RAMDISK_BASE_ADDRESS,
        NDOS_RAMDISK_SECTOR_COUNT,
        NDOS_RAMDISK_SECTOR_SIZE
    );

    if (device.read_sector(device.user_context, sector, saved) != FAT12_OK)
        return -20;

    for (index = 0; index < NDOS_RAMDISK_SECTOR_SIZE; ++index)
        test[index] = (uint8_t)(index ^ UINT32_C(0xA5));

    if (device.write_sector(device.user_context, sector, test) != FAT12_OK)
        return -21;

    for (index = 0; index < NDOS_RAMDISK_SECTOR_SIZE; ++index)
        test[index] = UINT8_C(0);

    if (device.read_sector(device.user_context, sector, test) != FAT12_OK)
        return -22;

    for (index = 0; index < NDOS_RAMDISK_SECTOR_SIZE; ++index) {
        if (test[index] != (uint8_t)(index ^ UINT32_C(0xA5))) {
            (void)device.write_sector(device.user_context, sector, saved);
            return -23;
        }
    }

    if (device.write_sector(device.user_context, sector, saved) != FAT12_OK)
        return -24;

    if (device.read_sector(device.user_context, NDOS_RAMDISK_SECTOR_COUNT, test)
        != FAT12_ERR_ARGUMENT)
        return -25;

    if (device.read_sector(device.user_context, UINT32_C(0), saved) != FAT12_OK)
        return -26;
    for (index = 0; index < NDOS_RAMDISK_SECTOR_SIZE; ++index)
        test[index] = UINT8_C(0);
    fat12_write_le16(&test[FAT12_BPB_BYTES_PER_SECTOR], UINT16_C(512));
    test[FAT12_BPB_SECTORS_PER_CLUSTER] = UINT8_C(1);
    fat12_write_le16(&test[FAT12_BPB_RESERVED_SECTORS], UINT16_C(1));
    test[FAT12_BPB_FAT_COUNT] = UINT8_C(2);
    fat12_write_le16(&test[FAT12_BPB_ROOT_ENTRY_COUNT], UINT16_C(128));
    fat12_write_le16(&test[FAT12_BPB_TOTAL_SECTORS_16], UINT16_C(1024));
    test[FAT12_BPB_MEDIA_DESCRIPTOR] = UINT8_C(0xF8);
    fat12_write_le16(&test[FAT12_BPB_SECTORS_PER_FAT], UINT16_C(3));
    test[FAT12_BOOT_SIGNATURE_LOW] = UINT8_C(0x55);
    test[FAT12_BOOT_SIGNATURE_HIGH] = UINT8_C(0xAA);
    if (device.write_sector(device.user_context, UINT32_C(0), test) != FAT12_OK)
        return -27;
    if (fat12_mount(&filesystem, &device, test) != FAT12_OK) {
        (void)device.write_sector(device.user_context, UINT32_C(0), saved);
        return -28;
    }
    if (filesystem.fat_start_sector != UINT32_C(1)
        || filesystem.root_start_sector != UINT32_C(7)
        || filesystem.data_start_sector != UINT32_C(15)
        || filesystem.cluster_count != UINT32_C(1009)) {
        (void)device.write_sector(device.user_context, UINT32_C(0), saved);
        return -29;
    }
    if (device.write_sector(device.user_context, UINT32_C(0), saved) != FAT12_OK)
        return -30;

    return 0;
}

int32_t ndos_mount_ramdisk(void)
{
    fat12_block_device device;
    fat12_filesystem filesystem;
    ndos_default_storage_context context;
    uint8_t *sector_buffer =
        (uint8_t *)(uintptr_t)NDOS_SECTOR_BUFFER_ADDRESS;
    fat12_status status;

    ndos_init_default_device(&device, &context);
    status = fat12_mount(&filesystem, &device, sector_buffer);
    if (status != FAT12_OK)
        return -(int32_t)status;

    if (filesystem.bytes_per_sector != NDOS_RAMDISK_SECTOR_SIZE
        || filesystem.total_sectors > device.sector_count
        || filesystem.fat_count == 0 || filesystem.sectors_per_fat == 0)
        return -100;

    return 0;
}

__attribute__((section(".text.ndos_mount_current_volume"), used))
int32_t ndos_mount_current_volume(void)
{
    fat12_block_device device;
    fat12_filesystem filesystem;
    ndos_default_storage_context context;
    uint8_t *sector_buffer =
        (uint8_t *)(uintptr_t)NDOS_SECTOR_BUFFER_ADDRESS;
    fat12_status status;
    uint32_t is_sdcard;

    is_sdcard = (NDOS_MAME_SDCARD_REGISTERS != UINT32_C(0)
        && ((((volatile uint32_t *)(uintptr_t)NDOS_MAME_SDCARD_REGISTERS)[0]
             & NDOS_MAME_SDCARD_PRESENT) != 0));
    ndos_init_default_device(&device, &context);
    status = fat12_mount(&filesystem, &device, sector_buffer);
    if (status != FAT12_OK)
        return -(int32_t)status;
    if (filesystem.bytes_per_sector != NDOS_RAMDISK_SECTOR_SIZE
        || filesystem.total_sectors > device.sector_count
        || filesystem.fat_count == 0 || filesystem.sectors_per_fat == 0)
        return -100;
    return is_sdcard ? 1 : 0;
}

int32_t ndos_format_ramdisk(void)
{
    static const uint8_t volume_label[11] = {
        'J', '6', '8', 'K', 'R', 'A', 'M', 'D', 'I', 'S', 'K'
    };
    fat12_block_device device;
    fat12_format_options options;
    ndos_ramdisk_context context;
    uint8_t *sector_buffer =
        (uint8_t *)(uintptr_t)NDOS_SECTOR_BUFFER_ADDRESS;
    fat12_status status;
    uint32_t index;

    ndos_init_default_ramdisk(&device, &context);

    options.total_sectors = NDOS_RAMDISK_SECTOR_COUNT;
    options.bytes_per_sector = NDOS_RAMDISK_SECTOR_SIZE;
    options.root_entry_count = UINT16_C(128);
    options.sectors_per_cluster = UINT8_C(1);
    options.fat_count = UINT8_C(2);
    options.media_descriptor = UINT8_C(0xF8);
    for (index = 0; index < UINT32_C(11); ++index)
        options.volume_label[index] = volume_label[index];

    status = fat12_format(&device, sector_buffer, &options);
    if (status != FAT12_OK)
        return -(int32_t)status;

    return 0;
}

__attribute__((section(".text.ndos_format_sdcard"), used))
int32_t ndos_format_sdcard(void)
{
    static const uint8_t volume_label[11] = {
        'J', '6', '8', 'K', 'S', 'D', 'C', 'A', 'R', 'D', ' '
    };
    fat12_block_device device;
    fat12_format_options options;
    ndos_sdcard_context context;
    volatile uint32_t *registers = (volatile uint32_t *)(uintptr_t)
        NDOS_MAME_SDCARD_REGISTERS;
    uint8_t *sector_buffer =
        (uint8_t *)(uintptr_t)NDOS_SECTOR_BUFFER_ADDRESS;
    uint32_t index;
    uint8_t sectors_per_cluster = UINT8_C(1);
    fat12_status status;

    if ((registers[0] & NDOS_MAME_SDCARD_PRESENT) == 0)
        return -(int32_t)FAT12_ERR_IO;
    context.registers = registers;
    context.sector_buffer = (volatile uint8_t *)(uintptr_t)
        NDOS_MAME_SDCARD_BUFFER;
    context.sector_count = registers[NDOS_MAME_SDCARD_COUNT / 4];
    if (context.sector_count == 0)
        return -(int32_t)FAT12_ERR_ARGUMENT;

    device.user_context = &context;
    device.read_sector = ndos_sdcard_read_sector;
    device.write_sector = ndos_sdcard_write_sector;
    device.sector_count = context.sector_count;
    device.sector_size = NDOS_RAMDISK_SECTOR_SIZE;

    /* Keep the data-cluster count in the FAT12 range for larger test images. */
    while ((device.sector_count / sectors_per_cluster)
           > FAT12_MAX_CLUSTER_COUNT) {
        if (sectors_per_cluster >= UINT8_C(128))
            return -(int32_t)FAT12_ERR_UNSUPPORTED;
        sectors_per_cluster = (uint8_t)(sectors_per_cluster << 1);
    }

    options.total_sectors = device.sector_count;
    options.bytes_per_sector = NDOS_RAMDISK_SECTOR_SIZE;
    options.root_entry_count = UINT16_C(128);
    options.sectors_per_cluster = sectors_per_cluster;
    options.fat_count = UINT8_C(2);
    options.media_descriptor = UINT8_C(0xF8);
    for (index = 0; index < UINT32_C(11); ++index)
        options.volume_label[index] = volume_label[index];

    status = fat12_format(&device, sector_buffer, &options);
    return status == FAT12_OK ? 0 : -(int32_t)status;
}

int32_t ndos_get_directory_entry(
    uint32_t visible_index,
    ndos_directory_entry *destination
)
{
    fat12_block_device device;
    fat12_directory_entry entry;
    fat12_filesystem filesystem;
    ndos_default_storage_context context;
    uint8_t *record = (uint8_t *)(uintptr_t)NDOS_SECTOR_BUFFER_ADDRESS;
    fat12_status status;
    uint32_t index;

    if (destination == NULL)
        return -(int32_t)FAT12_ERR_ARGUMENT;

    ndos_init_default_device(&device, &context);
    status = fat12_mount(&filesystem, &device, record);
    if (status != FAT12_OK)
        return -(int32_t)status;
    status = fat12_get_root_entry(&filesystem, record, visible_index, &entry);
    if (status == FAT12_ERR_NOT_FOUND)
        return 1;
    if (status != FAT12_OK)
        return -(int32_t)status;

    for (index = 0; index < UINT32_C(13); ++index)
        destination->name[index] = '\0';
    for (index = 0; index < UINT32_C(12)
         && entry.short_name[index] != '\0'; ++index)
        destination->name[index] = entry.short_name[index];
    destination->attributes = entry.attributes;
    destination->first_cluster = entry.first_cluster;
    destination->size = entry.size;
    destination->reserved = UINT32_C(0);
    return 0;
}

int32_t ndos_dir_get(uint32_t visible_index)
{
    ndos_directory_entry entry;
    uint8_t *record = (uint8_t *)(uintptr_t)NDOS_SECTOR_BUFFER_ADDRESS;
    uint32_t index;
    int32_t result = ndos_get_directory_entry(visible_index, &entry);

    if (result < 0)
        return result;
    if (result > 0)
        return 0;

    for (index = 0; index < UINT32_C(24); ++index)
        record[index] = UINT8_C(0);
    for (index = 0; index < UINT32_C(13); ++index)
        record[index] = (uint8_t)entry.name[index];
    record[16] = (uint8_t)(entry.size >> 24);
    record[17] = (uint8_t)(entry.size >> 16);
    record[18] = (uint8_t)(entry.size >> 8);
    record[19] = (uint8_t)entry.size;
    record[20] = (uint8_t)(entry.first_cluster >> 8);
    record[21] = (uint8_t)entry.first_cluster;
    record[22] = entry.attributes;
    return 1;
}

int32_t ndos_read_file(
    const char *name,
    uint8_t *destination,
    uint32_t destination_capacity,
    uint32_t *bytes_read
)
{
    fat12_block_device device;
    fat12_directory_entry entry;
    fat12_filesystem filesystem;
    ndos_default_storage_context context;
    uint8_t *sector_buffer =
        (uint8_t *)(uintptr_t)NDOS_SECTOR_BUFFER_ADDRESS;
    fat12_status status;

    ndos_init_default_device(&device, &context);
    status = fat12_mount(&filesystem, &device, sector_buffer);
    if (status != FAT12_OK)
        return -(int32_t)status;
    status = fat12_find_root_file(
        &filesystem, sector_buffer, name, &entry);
    if (status != FAT12_OK)
        return -(int32_t)status;
    status = fat12_read_file(
        &filesystem, sector_buffer, &entry, destination,
        destination_capacity, bytes_read);
    return status == FAT12_OK ? 0 : -(int32_t)status;
}

__attribute__((section(".text.ndos_test_sd_discovery"), used))
int32_t ndos_test_sd_discovery(void)
{
    static const char wanted_name[] = "SDCOPY.TXT";
    static const char expected_prefix[] = "J68K NDOS DEVELOPMENT DISK";
    ndos_directory_entry entry;
    uint8_t *destination = (uint8_t *)(uintptr_t)UINT32_C(0x00180200);
    uint32_t bytes_read = 0;
    uint32_t index;
    uint32_t character;
    int32_t result;
    uint32_t found = 0;

    /* Require the SD card, not the RAM-disk fallback. */
    result = ndos_mount_current_volume();
    if (result != 1)
        return -300;

    /* Exercise root enumeration, which is the filesystem path behind DIR. */
    for (index = 0; index < UINT32_C(224); ++index) {
        result = ndos_get_directory_entry(index, &entry);
        if (result < 0)
            return result;
        if (result > 0)
            break;
        for (character = 0; wanted_name[character] != '\0'; ++character) {
            if (entry.name[character] != wanted_name[character])
                break;
        }
        if (wanted_name[character] == '\0' && entry.name[character] == '\0') {
            found = 1;
            break;
        }
    }
    if (found == 0)
        return -301;

    /* Exercise root-name lookup and cluster-chain reading, used by TYPE/RUN. */
    result = ndos_read_file(
        wanted_name, destination, UINT32_C(141), &bytes_read);
    if (result != 0)
        return result;
    if (bytes_read != UINT32_C(141))
        return -302;
    for (character = 0; expected_prefix[character] != '\0'; ++character) {
        if (destination[character] != (uint8_t)expected_prefix[character])
            return -303;
    }
    return 0;
}

int32_t ndos_test_file_read(void)
{
    static const char test_name[] = "CHAIN.BIN";
    uint8_t *destination = (uint8_t *)(uintptr_t)UINT32_C(0x00180200);
    uint32_t bytes_read = 0;
    uint32_t index;
    int32_t result = ndos_read_file(
        test_name, destination, UINT32_C(700), &bytes_read);

    if (result != 0)
        return result;
    if (bytes_read != UINT32_C(700))
        return -200;
    for (index = 0; index < UINT32_C(512); ++index) {
        if (destination[index] != (uint8_t)(index ^ UINT32_C(0x5A)))
            return -201;
    }
    for (index = 0; index < UINT32_C(188); ++index) {
        if (destination[UINT32_C(512) + index]
            != (uint8_t)(index ^ UINT32_C(0xC3)))
            return -202;
    }
    return 0;
}

int32_t ndos_create_file(
    const char *name,
    const uint8_t *source,
    uint32_t size
)
{
    fat12_block_device device;
    fat12_filesystem filesystem;
    ndos_default_storage_context context;
    uint8_t *sector_buffer =
        (uint8_t *)(uintptr_t)NDOS_SECTOR_BUFFER_ADDRESS;
    fat12_status status;

    ndos_init_default_device(&device, &context);
    status = fat12_mount(&filesystem, &device, sector_buffer);
    if (status != FAT12_OK)
        return -(int32_t)status;
    status = fat12_create_file(
        &filesystem, sector_buffer, name, source, size, NULL);
    return status == FAT12_OK ? 0 : -(int32_t)status;
}

int32_t ndos_delete_file(const char *name)
{
    fat12_block_device device;
    fat12_filesystem filesystem;
    ndos_default_storage_context context;
    uint8_t *sector_buffer =
        (uint8_t *)(uintptr_t)NDOS_SECTOR_BUFFER_ADDRESS;
    fat12_status status;

    ndos_init_default_device(&device, &context);
    status = fat12_mount(&filesystem, &device, sector_buffer);
    if (status != FAT12_OK)
        return -(int32_t)status;
    status = fat12_delete_file(&filesystem, sector_buffer, name);
    return status == FAT12_OK ? 0 : -(int32_t)status;
}

__attribute__((section(".text.ndos_set_file_attributes"), used))
int32_t ndos_set_file_attributes(const char *name, uint8_t attributes)
{
    fat12_block_device device;
    fat12_filesystem filesystem;
    ndos_default_storage_context context;
    uint8_t *sector_buffer =
        (uint8_t *)(uintptr_t)NDOS_SECTOR_BUFFER_ADDRESS;
    fat12_status status;

    ndos_init_default_device(&device, &context);
    status = fat12_mount(&filesystem, &device, sector_buffer);
    if (status != FAT12_OK)
        return -(int32_t)status;
    status = fat12_set_file_attributes(
        &filesystem, sector_buffer, name, attributes);
    return status == FAT12_OK ? 0 : -(int32_t)status;
}

int32_t ndos_test_file_create(void)
{
    static const char name[] = "CREATE.BIN";
    uint8_t *source = (uint8_t *)(uintptr_t)UINT32_C(0x00180200);
    uint8_t *check = (uint8_t *)(uintptr_t)UINT32_C(0x00180600);
    uint32_t bytes_read = 0;
    uint32_t index;
    int32_t result;

    for (index = 0; index < UINT32_C(700); ++index)
        source[index] = (uint8_t)(index ^ UINT32_C(0x69));
    result = ndos_create_file(name, source, UINT32_C(700));
    if (result != 0)
        return result;
    result = ndos_read_file(name, check, UINT32_C(700), &bytes_read);
    if (result != 0)
        return result;
    if (bytes_read != UINT32_C(700))
        return -210;
    for (index = 0; index < UINT32_C(700); ++index) {
        if (check[index] != (uint8_t)(index ^ UINT32_C(0x69)))
            return -211;
    }
    return 0;
}

int32_t ndos_get_disk_free(
    uint32_t *free_clusters,
    uint32_t *free_bytes
)
{
    fat12_block_device device;
    fat12_filesystem filesystem;
    ndos_default_storage_context context;
    uint8_t *sector_buffer =
        (uint8_t *)(uintptr_t)NDOS_SECTOR_BUFFER_ADDRESS;
    fat12_status status;

    if (free_clusters == NULL || free_bytes == NULL)
        return -(int32_t)FAT12_ERR_ARGUMENT;
    ndos_init_default_device(&device, &context);
    status = fat12_mount(&filesystem, &device, sector_buffer);
    if (status != FAT12_OK)
        return -(int32_t)status;
    status = fat12_get_free_space(
        &filesystem, sector_buffer, free_clusters, free_bytes);
    return status == FAT12_OK ? 0 : -(int32_t)status;
}
