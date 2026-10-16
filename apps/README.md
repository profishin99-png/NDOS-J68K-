# NDOS application folders

Build.cmd automatically discovers and packages each app laid out as:

    apps/NAME/NAME.s

It produces build/apps/NAME.NEX and places NAME.NEX on the generated FAT12
system disk. NAME must use one to eight uppercase/lowercase letters or digits
because the current disk layer uses FAT 8.3 names.

Folders without a matching source, such as apps/template, are ignored. Copy
that starter into a new correctly named folder to begin an app.

For an established folder whose name cannot fit FAT 8.3, add app.json:

    { "disk_name": "SHORT" }

apps/yieldtest/app.json preserves the existing public YIELD.NEX name.

To keep unfinished work in the apps folder without building or installing it:

    { "enabled": false }
