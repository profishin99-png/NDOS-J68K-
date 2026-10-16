# NDOS 1.1 Rufus FAT12 test image

`Build-Rufus-Test-Image.cmd` creates
`build/disks/NDOS-1.1-RUFUS-TEST.img`.  It is a standard 1.44 MiB FAT12 image
with the current `NDOS.SYS` and generated `.NEX` applications.

Use it to test host-side FAT compatibility and to prepare removable media for
the future SD path.  It is not an x86 boot image and Rufus does not make a
J68K system bootable by writing it.  A real J68K boot requires the future
Rev-A SD controller, SD driver, and ROM BIOS loader.

In Rufus, select the removable test media and use the raw/DD-image write
workflow for `NDOS-1.1-RUFUS-TEST.img`.  Writing it overwrites the selected
removable media.  Do not select a drive containing files you need.

The existing `build/disks/ndos-system.img` remains the 512 KiB MAME RAM-disk
image and is not replaced by this workflow.
