# CUBE.NEX

`CUBE.NEX` is the first simple 3D-style framebuffer test for NDOS. It draws
two offset projected squares and connects their corners with fixed-point DDA
edges. The offset changes over time so the cube appears to rotate.

Run it from the DUART terminal:

```text
RUN CUBE.NEX
```

Press any key in the MAME window to invoke `NDOS_SYS_EXIT` and return to NDOS.
The program is an original wireframe test; it does not use Amiga source or
animation data.
