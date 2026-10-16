#include <stdint.h>
#include "ndos_video.h"
#include "ndos_input.h"
#define J68K_VIRTUAL_VIDEO_BASE UINT32_C(0x00e00000)
#define J68K_VIRTUAL_INPUT_BASE UINT32_C(0x00e10000)
#define J68K_VIRTUAL_INPUT_READY UINT32_C(0x80000000)
volatile uint8_t *ndos_video_framebuffer(void) { return (volatile uint8_t *)J68K_VIRTUAL_VIDEO_BASE; }
void ndos_video_clear(uint8_t colour) { volatile uint8_t *p=ndos_video_framebuffer(); uint32_t n; for(n=0;n<NDOS_VIDEO_WIDTH*NDOS_VIDEO_HEIGHT;++n) p[n]=colour; }
void ndos_video_put_pixel(uint16_t x,uint16_t y,uint8_t colour) { if(x<NDOS_VIDEO_WIDTH && y<NDOS_VIDEO_HEIGHT) ndos_video_framebuffer()[(uint32_t)y*NDOS_VIDEO_STRIDE+x]=colour; }
int32_t ndos_input_get_char(void) { volatile uint32_t *regs=(volatile uint32_t *)J68K_VIRTUAL_INPUT_BASE; if((regs[0]&J68K_VIRTUAL_INPUT_READY)==0) return NDOS_INPUT_NO_DATA; return (int32_t)(regs[1]>>24); }