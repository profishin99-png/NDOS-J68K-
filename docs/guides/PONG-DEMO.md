# NDOS Pong demo

Run `Run-Pong.cmd` to build, safely prepare the SD image, start J68K in MAME,
and automatically launch two Pong instances after NDOS boots. Other SD files
are preserved. Close any open J68K MAME window before running it, since the
mounted image cannot be changed while MAME is using it. To start manually, use
`RUN2 PONG.NEX` for the split-screen pair or `RUN PONG.NEX` for a single game
in the left half.

The game uses the temporary MAME-only 320x200 RGB332 framebuffer at the
address generated as `VIRTUAL_VIDEO_BASE` in `build/map.inc`. It draws in a
160x200 viewport: `RUN PONG.NEX` occupies the left half; `RUN2 PONG.NEX` runs
a second copy in the right half. Each copy clears and updates only its own
viewport, so neither can erase the other game's picture. It accepts held
keys from the MAME game window through `VIRTUAL_INPUT_BASE`, queued emulator
keys from the same interface, and serial-terminal keys through NDOS's
nonblocking `NDOS_SYS_POLLCHAR` call.

Hold **A** or **Left Arrow** to move left; hold **D** or **Right Arrow** to move
right. The paddle responds quickly and tops out at 8 pixels per 100 Hz tick.
A key tap gives it a short coast so one-shot terminal or emulator key events
still move it far enough to matter. The ball starts at 1 pixel per tick in each
axis, making its trips across the court easier to track and return.
The serial console accepts **A**, **D**, and **Q**. **Q** returns to the NDOS
shell. The yellow three-digit counter is the score (one point per paddle hit);
the red counter is missed balls. This is a small assembly demo and does not
define a physical J68K video or keyboard ABI.

`python tools/test_pong.py` runs an isolated MAME regression that checks the
framebuffer and HUD, forces one paddle hit and one miss to verify both
counters and that the visible yellow score changes, checks coast-and-stop
behavior, sends **D** and **Q**, then verifies
the game returns to NDOS. `python tools/test_pong_run2.py` checks both RUN2
instances select separate halves and draw both court edges.
