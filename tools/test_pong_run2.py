#!/usr/bin/env python3
"""Run two Pong NEX instances and verify their split framebuffer viewports."""
from __future__ import annotations

from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
RESULTS = BUILD / "test-results"
GENERATED_DISK = BUILD / "disks" / "ndos-sd.img"
TEST_IMAGE = RESULTS / "pong-run2-test.img"
RESULT = RESULTS / "pong-run2-result.txt"
LOG = RESULTS / "pong-run2-mame.log"
MAME = Path(os.environ.get(
    "J68K_MAME_EXE",
    str(ROOT.parent / "j68k-mame" / "bin" / "j68k-nvram.exe"),
))


def main() -> int:
    RESULTS.mkdir(parents=True, exist_ok=True)
    if not GENERATED_DISK.is_file() or not MAME.is_file():
        print("Build NDOS and the reduced MAME target first.", file=sys.stderr)
        return 2
    shutil.copyfile(GENERATED_DISK, TEST_IMAGE)
    RESULT.unlink(missing_ok=True)
    command = [
        str(MAME), "j68k", "-rompath", str(BUILD / "roms"),
        "-nvram_directory", str(RESULTS / "pong-run2-nvram"),
        "-sdcard", str(TEST_IMAGE),
        "-autoboot_script", str(ROOT / "luatests" / "test-pong-run2.lua"),
        "-video", "none", "-sound", "none", "-skip_gameinfo",
        "-nothrottle", "-seconds_to_run", "30", "-log",
    ]
    with LOG.open("w", encoding="utf-8", errors="replace") as output:
        completed = subprocess.run(command, cwd=ROOT, stdout=output,
                                   stderr=subprocess.STDOUT, check=False)
    log = LOG.read_text(encoding="utf-8", errors="replace")
    if completed.returncode != 0 or "[LUA ERROR]" in log:
        print(f"RUN2 PONG regression failed; see {LOG}", file=sys.stderr)
        return completed.returncode or 1
    if not RESULT.is_file():
        print(f"MAME did not write {RESULT}; see {LOG}", file=sys.stderr)
        return 1
    print(RESULT.read_text(encoding="utf-8").strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
