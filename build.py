"""Build freestanding C, assemble NDOS, and generate the split boot ROM."""
from pathlib import Path
import json, re, subprocess, sys, struct
ROOT = Path(__file__).resolve().parent
VASM = ROOT.parent / 'j68k-vasm/vasmm68k_mot.exe'
GCC_BIN = ROOT.parent / 'j68k-gcc/toolchain/m68k-elf/bin'
GCC = GCC_BIN / 'm68k-elf-gcc.exe'
LD = GCC_BIN / 'm68k-elf-ld.exe'
OBJCOPY = GCC_BIN / 'm68k-elf-objcopy.exe'
NM = GCC_BIN / 'm68k-elf-nm.exe'
BUILD = ROOT / 'build'
BUILD.mkdir(exist_ok=True)
(BUILD / 'test-results').mkdir(exist_ok=True)

def discover_apps():
    """Return sorted (disk-name, assembly-source) pairs for NDOS apps."""
    discovered = []
    seen_disk_names = set()
    for app_dir in sorted((ROOT / 'apps').iterdir(),
                          key=lambda path: path.name):
        if not app_dir.is_dir():
            continue
        source = app_dir / f'{app_dir.name}.s'
        if not source.is_file():
            continue
        metadata_path = app_dir / 'app.json'
        disk_name = app_dir.name.upper()
        if metadata_path.is_file():
            metadata = json.loads(metadata_path.read_text(encoding='utf-8'))
            if metadata.get('enabled', True) is not True:
                continue
            disk_name = metadata.get('disk_name', disk_name).upper()
        if re.fullmatch(r'[A-Z0-9]{1,8}', disk_name) is None:
            raise AssertionError(
                f'app {app_dir.name!r} needs a FAT 8.3 disk_name in app.json'
            )
        if disk_name in seen_disk_names:
            raise AssertionError(f'duplicate app disk name: {disk_name}.NEX')
        seen_disk_names.add(disk_name)
        discovered.append((disk_name, source.relative_to(ROOT).as_posix()))
    return discovered

try:
    for tool in (GCC, LD, OBJCOPY, NM, VASM):
        assert tool.is_file(), f'missing build tool: {tool}'

    text = (ROOT.parent / 'j68k-mame/src/j68k_map.h').read_text()
    constants = re.findall(r'constexpr u32 (\w+) = (0x[0-9a-f]+|[0-9]+);', text)
    (BUILD / 'map.inc').write_text('\n'.join(f'{name} equ ${int(value,0):X}' for name,value in constants)+'\n')

    c_object = BUILD / 'ndos_c.o'
    fat12_object = BUILD / 'fat12.o'
    block_object = BUILD / 'ndos_block.o'
    video_object = BUILD / 'ndos_video.o'
    quicc_play_object = BUILD / 'ndos_quicc_play.o'
    c_elf = BUILD / 'ndos_c.elf'
    c_binary = BUILD / 'ndos_c.bin'
    subprocess.run([
        str(GCC), '-mcpu=68020', '-msoft-float', '-Os', '-std=c11',
        '-ffreestanding', '-fno-builtin', '-fno-stack-protector', '-fno-common',
        '-fno-pic', '-fno-pie', '-ffunction-sections', '-fdata-sections',
        '-Wall', '-Wextra', '-Werror', '-c', 'c/ndos_c.c', '-o', str(c_object)
    ], cwd=ROOT, check=True)
    subprocess.run([
        str(GCC), '-mcpu=68020', '-msoft-float', '-Os', '-std=c11',
        '-ffreestanding', '-fno-builtin', '-fno-stack-protector', '-fno-common',
        '-fno-pic', '-fno-pie', '-ffunction-sections', '-fdata-sections',
        '-Wall', '-Wextra', '-Werror', '-pedantic', '-Ic/fat12',
        '-c', 'c/fat12/fat12.c', '-o', str(fat12_object)
    ], cwd=ROOT, check=True)
    subprocess.run([
        str(GCC), '-mcpu=68020', '-msoft-float', '-Os', '-std=c11',
        '-ffreestanding', '-fno-builtin', '-fno-stack-protector', '-fno-common',
        '-fno-pic', '-fno-pie', '-ffunction-sections', '-fdata-sections',
        '-Wall', '-Wextra', '-Werror', '-pedantic', '-Ic/fat12', '-Ic/platform',
        '-c', 'c/platform/ndos_block.c', '-o', str(block_object)
    ], cwd=ROOT, check=True)
    subprocess.run([
        str(GCC), '-mcpu=68020', '-msoft-float', '-Os', '-std=c11',
        '-ffreestanding', '-fno-builtin', '-fno-stack-protector', '-fno-common',
        '-fno-pic', '-fno-pie', '-ffunction-sections', '-fdata-sections',
        '-Wall', '-Wextra', '-Werror', '-pedantic', '-Ic/platform',
        '-c', 'c/platform/ndos_video.c', '-o', str(video_object)
    ], cwd=ROOT, check=True)
    subprocess.run([
        str(GCC), '-mcpu=68020', '-msoft-float', '-Os', '-std=c11',
        '-ffreestanding', '-fno-builtin', '-fno-stack-protector', '-fno-common',
        '-fno-pic', '-fno-pie', '-ffunction-sections', '-fdata-sections',
        '-Wall', '-Wextra', '-Werror', '-pedantic', '-Ic/platform',
        '-c', 'c/platform/ndos_quicc_play.c', '-o', str(quicc_play_object)
    ], cwd=ROOT, check=True)
    subprocess.run([
        str(LD), '-T', 'c/ndos-c.ld', '--gc-sections', '--build-id=none',
        '-Map', str(BUILD / 'ndos_c.map'), '-o', str(c_elf),
        str(c_object), str(fat12_object), str(block_object), str(video_object),
        str(quicc_play_object)
    ], cwd=ROOT, check=True)
    subprocess.run([str(OBJCOPY), '-O', 'binary', str(c_elf), str(c_binary)], check=True)

    nm_text = subprocess.check_output(
        [str(NM), '-g', '--defined-only', str(c_elf)], text=True
    )
    symbols = {}
    for line in nm_text.splitlines():
        match = re.fullmatch(r'([0-9a-fA-F]+)\s+\w\s+(\w+)', line.strip())
        if match:
            symbols[match.group(2)] = int(match.group(1), 16)
    assert 'ndos_c_selftest' in symbols, 'C entry symbol is missing'
    assert 'fat12_test_endian' in symbols, 'FAT12 endian test was discarded'
    assert 'ndos_test_ramdisk_adapter' in symbols, 'RAM-disk adapter test was discarded'
    assert 0xC000 <= symbols['ndos_c_selftest'] < 0x10000, 'C entry is outside its region'
    (BUILD / 'c-map.inc').write_text('\n'.join(
        f'{name.upper()} equ ${address:X}' for name, address in sorted(symbols.items())
    ) + '\n')

    for source, listing, binary in [
        ('ndos.s', 'ndos.lst', 'ndos.bin'),
        ('boot.s', 'boot.lst', 'boot.bin'),
        ('hello-nex.s', 'HELLO.NEX.lst', 'HELLO.NEX'),
    ]:
        subprocess.run([str(VASM), '-m68020', '-m68882', '-Fbin',
                        '-L', f'build/{listing}', '-o', f'build/{binary}',
                        source], cwd=ROOT, check=True)
    app_build = BUILD / 'apps'
    app_build.mkdir(exist_ok=True)
    apps = discover_apps()
    for app_name, app_source in apps:
        payload = app_build / f'{app_name}.bin'
        nex = app_build / f'{app_name}.NEX'
        subprocess.run([str(VASM), '-m68020', '-m68882', '-Fbin',
                        '-L', str(app_build / f'{app_name}.lst'),
                        '-o', str(payload), app_source], cwd=ROOT, check=True)
        subprocess.run([sys.executable, 'tools/nexpack.py', str(payload),
                        str(nex), '--entry', '0', '--stack', '1024'],
                       cwd=ROOT, check=True)
    disk_manifest = json.loads((ROOT / 'disk/system.json').read_text(
        encoding='utf-8'))
    generated_apps = [
        {'source': f'build/apps/{app_name}.NEX',
         'destination': f'{app_name}.NEX'}
        for app_name, _ in apps
    ]
    # A generated Doom test package is opt-in: it exists only after
    # tools/doompackage.py has installed disk/files/doom/DOOMLOAD.JSON.
    # Keep normal NDOS images and their public NEX ABI unchanged otherwise.
    doom_manifest_path = ROOT / 'disk/files/doom/DOOMLOAD.JSON'
    doom_files = []
    if doom_manifest_path.is_file():
        doom_manifest = json.loads(doom_manifest_path.read_text(encoding='utf-8'))
        if doom_manifest.get('format') != 'J68K-DOOM-CHUNKS-1':
            raise AssertionError('invalid experimental Doom chunk manifest')
        for chunk in doom_manifest.get('chunks', []):
            name = chunk.get('name')
            if not isinstance(name, str) or not re.fullmatch(r'[A-Z0-9]{1,8}\.BIN', name):
                raise AssertionError('invalid experimental Doom chunk name')
            source = ROOT / 'disk/files/doom' / name
            if not source.is_file() or source.stat().st_size != chunk.get('bytes'):
                raise AssertionError(f'missing or mismatched experimental Doom chunk: {name}')
            doom_files.append({'source': f'disk/files/doom/{name}', 'destination': name})
    disk_manifest['files'] = (
        disk_manifest['files'][:1]
        + generated_apps
        + doom_files
        + disk_manifest['files'][1:]
    )
    generated_manifest = BUILD / 'system.json'
    generated_manifest.write_text(
        json.dumps(disk_manifest, indent=2) + '\n', encoding='utf-8')
    subprocess.run([
        sys.executable, 'tools/make_disk.py', str(generated_manifest),
        'build/disks/ndos-system.img'
    ], cwd=ROOT, check=True)
    subprocess.run([
        sys.executable, 'tools/make_disk.py', str(generated_manifest),
        'build/disks/ndos-sd.img', '--layout', 'floppy-1440k'
    ], cwd=ROOT, check=True)
    rom = (BUILD / 'boot.bin').read_bytes()
    assert len(rom) == 0x100000, 'ROM must be exactly 1 MiB'
    assert struct.unpack('>II',rom[:8]) == (0x1ff000,0x100)
    target = BUILD / 'roms/j68k'
    target.mkdir(parents=True,exist_ok=True)
    for filename, offset in [('j68k_diag_hi.bin',0),('j68k_diag_lo.bin',2)]:
        (target/filename).write_bytes(b''.join(rom[i+offset:i+offset+2] for i in range(0,len(rom),4)))
    print('PASS: NDOS, NEX apps, 512 KiB RAM disk, 1.44 MiB FAT12 SD image, and split 1 MiB ROM built.')
except (subprocess.CalledProcessError, OSError, AssertionError) as exc:
    print(f'BUILD FAILED: {exc}',file=sys.stderr)
    sys.exit(1)
