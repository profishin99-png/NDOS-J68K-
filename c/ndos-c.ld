OUTPUT_FORMAT("elf32-m68k")
OUTPUT_ARCH(m68k)
ENTRY(ndos_c_selftest)

SECTIONS
{
    . = 0x0000C000;

    .text :
    {
        KEEP(*(.text.ndos_c_selftest))
        KEEP(*(.text.fat12_format))
        KEEP(*(.text.ndos_format_ramdisk))
        KEEP(*(.text.ndos_format_sdcard))
        KEEP(*(.text.ndos_mount_ramdisk))
        KEEP(*(.text.ndos_mount_current_volume))
        KEEP(*(.text.ndos_dir_get))
        KEEP(*(.text.ndos_get_directory_entry))
        KEEP(*(.text.ndos_read_file))
        KEEP(*(.text.ndos_test_sd_discovery))
        KEEP(*(.text.ndos_test_file_read))
        KEEP(*(.text.ndos_create_file))
        KEEP(*(.text.ndos_delete_file))
        KEEP(*(.text.ndos_set_file_attributes))
        KEEP(*(.text.ndos_test_file_create))
        KEEP(*(.text.ndos_get_disk_free))
        *(.text .text.*)
    }

    .rodata : { *(.rodata .rodata.*) }
    .data   : { *(.data .data.*) }
    .bss (NOLOAD) : { *(.bss .bss.* COMMON) }

    /DISCARD/ :
    {
        *(.comment)
        *(.note .note.*)
        *(.eh_frame .eh_frame.*)
    }

    ASSERT(SIZEOF(.bss) == 0, "NDOS C BSS needs startup initialization")
    ASSERT(. <= 0x00010000, "NDOS C image overlaps the NEX region")
}
