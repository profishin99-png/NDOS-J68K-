#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "../c/fat12/fat12_internal.h"

#define SECTORS 128u
#define BPS 512u
static uint8_t disk[SECTORS][BPS];

static fat12_status read_sector(void *context, uint32_t sector, uint8_t *out)
{
    (void)context;
    if (sector >= SECTORS) return FAT12_ERR_IO;
    memcpy(out, disk[sector], BPS);
    return FAT12_OK;
}

static fat12_status write_sector(void *context, uint32_t sector, const uint8_t *in)
{
    (void)context;
    if (sector >= SECTORS) return FAT12_ERR_IO;
    memcpy(disk[sector], in, BPS);
    return FAT12_OK;
}

static int fail(const char *message)
{
    fprintf(stderr, "FAIL: %s\n", message);
    return 1;
}

int main(void)
{
    static const uint8_t label[11] =
        { 'J','6','8','K','T','E','S','T',' ',' ',' ' };
    fat12_block_device device = { 0, read_sector, write_sector, SECTORS, BPS };
    fat12_format_options options = { SECTORS, BPS, 64, 1, 2, 0xF8, {0} };
    fat12_filesystem filesystem;
    fat12_directory_entry entry;
    uint8_t sector[BPS];
    uint8_t output[700];
    uint8_t canonical[11];
    uint32_t bytes_read = 0;
    uint32_t free_clusters = 0;
    uint32_t free_bytes = 0;
    uint32_t index;

    memcpy(options.volume_label, label, sizeof(label));
    if (fat12_format(&device, sector, &options) != FAT12_OK)
        return fail("format");
    if (fat12_mount(&filesystem, &device, sector) != FAT12_OK)
        return fail("mount");
    if (fat12_get_free_space(&filesystem, sector, &free_clusters, &free_bytes)
        != FAT12_OK || free_clusters != 121 || free_bytes != 61952)
        return fail("empty-volume free space");
    if (fat12_make_short_name("chain.bin", canonical) != FAT12_OK
        || memcmp(canonical, "CHAIN   BIN", 11) != 0)
        return fail("8.3 conversion");
    if (fat12_make_short_name("TOO-LONG-NAME.BIN", canonical)
        != FAT12_ERR_INVALID_NAME)
        return fail("invalid 8.3 name");

    memset(sector, 0, sizeof(sector));
    memcpy(sector, "CHAIN   BIN", 11);
    sector[11] = 0x20;
    fat12_write_le16(&sector[26], 2);
    fat12_write_le32(&sector[28], 700);
    if (write_sector(0, filesystem.root_start_sector, sector) != FAT12_OK)
        return fail("root write");

    memcpy(sector, disk[filesystem.fat_start_sector], BPS);
    fat12_set_entry(sector, 2, 5);
    fat12_set_entry(sector, 5, 0xFFF);
    memcpy(disk[filesystem.fat_start_sector], sector, BPS);
    memcpy(disk[filesystem.fat_start_sector + filesystem.sectors_per_fat],
           sector, BPS);
    for (index = 0; index < BPS; ++index)
        disk[filesystem.data_start_sector][index] = (uint8_t)(index ^ 0x5A);
    for (index = 0; index < BPS; ++index)
        disk[filesystem.data_start_sector + 3][index] = (uint8_t)(index ^ 0xC3);

    if (fat12_find_root_file(&filesystem, sector, "chain.bin", &entry)
        != FAT12_OK)
        return fail("case-insensitive lookup");
    if (entry.first_cluster != 2 || entry.size != 700
        || strcmp(entry.short_name, "CHAIN.BIN") != 0)
        return fail("directory metadata");
    if (fat12_read_file(&filesystem, sector, &entry, output, 699, &bytes_read)
        != FAT12_ERR_BUFFER_TOO_SMALL)
        return fail("capacity guard");
    if (fat12_read_file(&filesystem, sector, &entry, output, sizeof(output),
                        &bytes_read) != FAT12_OK || bytes_read != 700)
        return fail("cluster-chain read");
    for (index = 0; index < 512; ++index)
        if (output[index] != (uint8_t)(index ^ 0x5A))
            return fail("cluster 2 payload");
    for (index = 0; index < 188; ++index)
        if (output[512 + index] != (uint8_t)(index ^ 0xC3))
            return fail("cluster 5 payload");

    for (index = 0; index < sizeof(output); ++index)
        output[index] = (uint8_t)(index ^ 0x96);
    if (fat12_create_file(&filesystem, sector, "new.txt", output,
                          sizeof(output), &entry) != FAT12_OK)
        return fail("create file");
    if (entry.first_cluster != 3 || entry.size != sizeof(output)
        || strcmp(entry.short_name, "NEW.TXT") != 0)
        return fail("created metadata");
    if (fat12_create_file(&filesystem, sector, "NEW.TXT", output,
                          sizeof(output), 0) != FAT12_ERR_ALREADY_EXISTS)
        return fail("duplicate rejection");
    memset(output, 0, sizeof(output));
    if (fat12_find_root_file(&filesystem, sector, "NEW.TXT", &entry)
        != FAT12_OK
        || fat12_read_file(&filesystem, sector, &entry, output,
                           sizeof(output), &bytes_read) != FAT12_OK)
        return fail("read created file");
    for (index = 0; index < sizeof(output); ++index)
        if (output[index] != (uint8_t)(index ^ 0x96))
            return fail("created payload");
    if (fat12_get_entry(disk[filesystem.fat_start_sector], 3) != 4
        || fat12_get_entry(disk[filesystem.fat_start_sector], 4) != 0xFFF
        || memcmp(disk[filesystem.fat_start_sector],
                  disk[filesystem.fat_start_sector
                       + filesystem.sectors_per_fat], BPS) != 0)
        return fail("allocated FAT chain");
    if (fat12_create_file(&filesystem, sector, "EMPTY.TXT", 0, 0, &entry)
        != FAT12_OK || entry.first_cluster != 0 || entry.size != 0)
        return fail("empty file");
    if (fat12_get_free_space(&filesystem, sector, &free_clusters, &free_bytes)
        != FAT12_OK || free_clusters != 117 || free_bytes != 59904)
        return fail("allocated-volume free space");

    memcpy(sector, disk[filesystem.fat_start_sector + filesystem.sectors_per_fat], BPS);
    fat12_set_entry(sector, 2, 6);
    memcpy(disk[filesystem.fat_start_sector + filesystem.sectors_per_fat], sector, BPS);
    if (fat12_find_root_file(&filesystem, sector, "CHAIN.BIN", &entry)
        != FAT12_OK)
        return fail("find mismatch fixture");
    if (fat12_read_file(&filesystem, sector, &entry, output, sizeof(output), 0)
        != FAT12_ERR_CORRUPT_CHAIN)
        return fail("FAT-copy mismatch detection");

    puts("PASS: lookup, reads, file creation, allocation, and FAT-copy validation");
    return 0;
}
