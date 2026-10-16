# NDOS File-I/O Abstraction and Future File Policy

**Scope:** portable kernel file API above the present FAT12 adapter.  
**Status:** design boundary; no new syscall numbers or on-disk metadata are frozen by this document.

## Rule: applications do not call FAT12 directly

NDOS application code must depend on NDOS file syscalls and SDK structures. The kernel owns backend selection. FAT12 is the current backend; a future FAT16, FAT32, SD-card, RAM-disk, or host-backed image implementation must fit below the same NDOS file API.

```text
NEX application
    -> NDOS syscall / SDK file API
        -> kernel handle table and policy checks
            -> NDOS filesystem adapter
                -> FAT12 today, another filesystem later
                    -> block device adapter
                        -> RAM disk today, SD/IDE/ISA storage later
```

The current code already has the lowest two layers:

| Layer | Existing implementation | Status |
|---|---|---|
| Block device | sector callbacks in `fat12_block_device` | VERIFIED |
| RAM-disk platform adapter | `ndos_ramdisk_*` | VERIFIED |
| FAT12 volume parser/read/create/delete | portable `fat12_*` code | VERIFIED baseline |
| NDOS named-file wrapper | `ndos_read_file`, `ndos_create_file`, `ndos_delete_file` | VERIFIED |
| Open-handle table | none | DEFERRED |
| Streaming read/write API | none | DEFERRED |
| Permission policy | none | DEFERRED |

## Handle API direction

Do not add applications that manipulate FAT cluster numbers, root-sector offsets, or FAT attributes directly. The future kernel API will operate on opaque small integer handles.

```text
OPEN(path, flags)        -> handle or negative NDOS error
READ(handle, buffer, n)  -> byte count or negative error
WRITE(handle, buffer, n) -> byte count or negative error
SEEK(handle, offset, whence) -> new offset or negative error
CLOSE(handle)            -> zero or negative error
STAT(path, info)         -> metadata structure or negative error
SETATTR(path, attrs)     -> zero or negative error
```

The syscall numbers, register ABI, maximum open-file count, seek origin values, and structure layout remain **PROPOSED** until the current syscall set is documented as stable enough to extend.

First implementation should support only:

```text
8.3 root-directory paths
regular files
read-only streaming
one shared filesystem volume
bounded handle count
```

Add write, append, truncate, directories, long names, and multiple volumes one at a time.

## File attributes are not file permissions

FAT12 has attributes. They are compatible metadata flags, not a security system:

| FAT bit | Name | Meaning in NDOS initially |
|---:|---|---|
| `$01` | Read-only | Kernel should reject ordinary write/truncate/delete unless a supervisor policy explicitly overrides it |
| `$02` | Hidden | `DIR` and `LS.NEX` omit it by default; an explicit option later shows it |
| `$04` | System | Reserved for NDOS system files or boot files; policy remains PROPOSED |
| `$08` | Volume label | Not a regular file |
| `$10` | Directory | Future directory support; current FAT12 root implementation filters it |
| `$20` | Archive | Preserve and update only when write support is complete |
| `$0F` | Long-name record | Special FAT record; unsupported in the first filesystem API |

`HIDDEN` is a presentation choice. It does not protect file contents. `READ_ONLY` can be enforced by the NDOS kernel, but only after write/truncate/delete operations are routed through the common handle/policy layer.

## Future NDOS permissions

Real permissions need a user/process identity model. FAT12 stores no owner UID, group, access control list, or execute permission. Therefore permissions must be NDOS metadata rather than silently reinterpreting FAT bytes.

A later NDOS policy record may contain:

```text
file identity / canonical short name
owner process or user ID
owner permissions: read, write, execute
system permissions: read, write, execute
hidden/system policy flags
creation/modification metadata
```

The storage location for that metadata is **UNRESOLVED**. Choices to review later include a protected `NDOS.MET` sidecar file, a kernel-owned metadata directory once directories exist, or an NDOS-specific extended filesystem. Do not reserve a fake FAT12 field for it.

Initial NDOS has one operator at the serial console. The first enforceable distinction should be:

```text
user task
vs.
supervisor kernel
```

Then add per-file read-only and hidden behavior. Multi-user accounts, groups, and ACLs should wait until processes, region protection, and persistent user identity exist.

## Compatibility rules

1. Existing syscalls 9, 10, 11, and 13 remain supported as convenience whole-file calls.
2. New applications use handle calls once they exist.
3. `CAT.NEX`, `LS.NEX`, `WRITE.NEX`, and `DELETE.NEX` may be migrated internally later, but their command behavior stays stable.
4. FAT12 remains a backend implementation detail outside the filesystem adapter.
5. Host import/export tools must use the same canonical naming and policy validation as NDOS where possible.
6. Hidden and system files must never be used as a substitute for memory protection.

## Implementation order

1. Finish Scheduler Rev. 1 cooperative test; it provides a safe kernel execution base.
2. Define the public `ndos_file_info` and opaque-handle SDK structures.
3. Add a kernel-only handle table with fixed bounds and no user-supplied pointers stored persistently.
4. Add `OPEN`, `READ`, and `CLOSE` for read-only streaming.
5. Write a `MORE.NEX` or streaming `CAT.NEX` test that reads a file in small chunks.
6. Add `STAT` and expose FAT read-only/hidden attributes.
7. Make `DIR` hide hidden files by default; add an explicit show-hidden option.
8. Add write/append/truncate only after allocation rollback and error recovery are tested.
9. Add NDOS-specific permission metadata after user/process identity exists.
10. Replace the RAM-disk backend with a larger virtual/SD backend without changing NEX application ABI.
