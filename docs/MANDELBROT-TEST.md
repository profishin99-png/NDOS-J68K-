# Mandelbrot NEX test

`MANDELB.NEX` is a single-precision MC68881/MC68882 rendering test for
the temporary MAME-only framebuffer. It runs the orbit calculations through
the floating-point registers, renders a 160x100 image, and doubles each pixel
to fill the 320x200 display. The current iteration limit is 10000. Points that
escape are colored by iteration count; points inside the set are black. The app
reports elapsed render time in seconds to hundredths and total 100 Hz ticks.
One tick represents 0.01 seconds in the current MAME development timer model.

The pixel coordinates remain in FP2/FP3 and the iteration count remains in D6.
The squared radius stays in FP7 and is compared against 4.0 using the FPU,
avoiding a scratch-memory write/read on every iteration. Once the escape count
is known, one aligned word store paints the two horizontally doubled pixels;
the completed row is copied to the next scanline with word transfers.

The program uses the requested register plan:

| Register | Use |
|---|---|
| FP0 | Current real orbit coordinate, x |
| FP1 | Current imaginary orbit coordinate, y |
| FP2 | Pixel coordinate, c-real |
| FP3 | Pixel coordinate, c-imaginary |
| FP4 | x squared, then next x |
| FP5 | y squared |
| FP6 | temporary and next y |
| FP7 | squared radius, x squared plus y squared |

The escape limit is `x*x + y*y > 4.0`. The radius is stored as an IEEE-754
single and compared using the FPU condition codes. All embedded floating
constants are explicitly PC-relative so the NEX can load away from address 0.

## Build and run

From this directory, run `Build.cmd`, then `Run-NDOS.cmd`. In the NDOS serial
terminal, enter:

```text
RUN MANDELB.NEX
```

The drawing is a one-shot test and returns to the shell when complete. The
generated application is `build/apps/MANDELB.NEX`; the SD image containing it
is `build/disks/ndos-sd.img`.

## Automated test

Run `tools/test_mandelbrot.py`. It uses a private copy of the generated SD
image, boots reduced MAME, runs the application, and checks that it is either
still rendering or has returned to NDOS, with non-black pixels and multiple
colors in the framebuffer. The 10-minute emulated-time limit keeps the test
bounded; with the 10000 iteration limit, the result may report
`STATUS=IN_PROGRESS`. The Lua test also saves `mandelbrot.png` for visual review.

This validates assembly, NEX packaging, and the reduced MAME model only. The
framebuffer at `$00E00000` is provisional MAME graphics hardware; this test
does not define the Rev-A video-card interface or demonstrate physical video.
