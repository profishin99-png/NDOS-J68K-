# J68K virtual-disk workflow

Use `Disk-Manager.cmd` for the normal MAME disk workflow. It opens a Python/Tkinter interface that displays both the generated system disk and the live MAME NVRAM disk, including their FAT12 file lists.

The **Install Generated Disk** action:

1. Refuses to run while any `j68k-nvram.exe` process exists.
2. Validates the generated 512 KiB J68K FAT12 image.
3. Makes a timestamped backup under `disk/backup/`.
4. Copies through a temporary file and atomically replaces `disk/j68k/ramdisk`.
5. Re-validates the installed FAT12 directory and confirms it equals the generated disk.

The **Import PC File** action uses the same MAME-closed guard and atomic FAT12 update as the existing importer.

`Install-Disk.cmd` is now the command-line equivalent of the GUI install action. It returns a clear error with the active MAME PIDs instead of copying while MAME owns an in-memory disk.

Start MAME only after the install or import finishes. In NDOS, use `DIR` to confirm the file list.

The NVRAM file still preserves an older 8 MiB virtual-card tail when it installs a new RAM disk, but the SD controller no longer uses that tail. The active MAME SD image is `disk/j68k/sdcard.img`, managed separately by `Install-SD-Card.cmd`; see [MAME-SD-BOOT.md](MAME-SD-BOOT.md).
