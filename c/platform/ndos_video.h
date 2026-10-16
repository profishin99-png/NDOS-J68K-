#ifndef NDOS_VIDEO_H
#define NDOS_VIDEO_H
#include <stdint.h>
#define NDOS_VIDEO_WIDTH 320u
#define NDOS_VIDEO_HEIGHT 200u
#define NDOS_VIDEO_STRIDE 320u
/* Temporary MAME indexed framebuffer ABI.  Replace only this backend when CPLD2/ISA VGA exists. */
volatile uint8_t *ndos_video_framebuffer(void);
void ndos_video_clear(uint8_t colour);
void ndos_video_put_pixel(uint16_t x, uint16_t y, uint8_t colour);
#endif