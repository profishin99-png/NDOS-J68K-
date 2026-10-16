# NDOS Pong demo

Run `Run-Pong.cmd` to build, safely back up the live SD image, install or replace
only `PONG.NEX` on it, start J68K in MAME, and automatically launch Pong after
NDOS boots. Other SD files are preserved. Close any open J68K MAME window before
running it, since the mounted image cannot be changed while MAME is using it.
To start it manually after installing the app, use `Run-NDOS.cmd` and enter
`RUN PONG.NEX` at the NDOS prompt.

The game uses the temporary MAME-only 320x200 RGB332 framebuffer at the
address generated as `VIRTUAL_VIDEO_BASE` in `build/map.inc`. It accepts held
keys from the MAME game window through `VIRTUAL_INPUT_BASE`, queued emulator
keys from the same interface, and serial-terminal keys through NDOS's
nonblocking `NDOS_SYS_POLLCHAR` call.

Hold **A** or **Left Arrow** to move left; hold **D** or **Right Arrow** to move
right. The paddle accelerates to 7 pixels per 100 Hz game tick. A tap adds a
small push, and releasing a key lets it coast briefly before friction stops it.
The serial console accepts **A**, **D**, and **Q**. **Q** returns to the NDOS
shell. The yellow three-digit counter is the score (one point per paddle hit);
the red counter is missed balls. This is a small assembly demo and does not
define a physical J68K video or keyboard ABI.

`python tools/test_pong.py` runs an isolated MAME regression that checks the
framebuffer and HUD, forces one paddle hit and one miss to verify both
counters, checks coast-and-stop behavior, sends **D** and **Q**, then verifies
the game returns to NDOS.
