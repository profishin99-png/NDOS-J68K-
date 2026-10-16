#include <stdint.h>
#include "ndos_quicc_play.h"

/* The only place this fictional MAME playground address is defined in C. */
#define J68K_QUICC_PLAY_BASE UINT32_C(0x00e20000)
enum {
    QP_COMMAND = 0, QP_STATUS = 1, QP_COLOUR = 2, QP_X0 = 3,
    QP_Y0 = 4, QP_X1 = 5, QP_Y1 = 6, QP_WORKERS = 7,
    QP_COMMAND_COUNT = 8, QP_HEARTBEAT_A = 9, QP_HEARTBEAT_B = 10
};
enum { QP_CLEAR = 1, QP_FILL_RECT = 2, QP_LINE = 3, QP_CHECKERBOARD = 4 };

static volatile uint32_t *const qp = (volatile uint32_t *)J68K_QUICC_PLAY_BASE;
static void qp_setup(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint8_t colour, uint32_t workers)
{
    qp[QP_COLOUR] = colour;
    qp[QP_X0] = x0; qp[QP_Y0] = y0;
    qp[QP_X1] = x1; qp[QP_Y1] = y1;
    qp[QP_WORKERS] = workers & NDOS_QUICC_PLAY_BOTH_WORKERS;
}
uint32_t ndos_quicc_play_status(void) { return qp[QP_STATUS]; }
uint32_t ndos_quicc_play_command_count(void) { return qp[QP_COMMAND_COUNT]; }
uint32_t ndos_quicc_play_heartbeat(unsigned worker) { return qp[worker ? QP_HEARTBEAT_B : QP_HEARTBEAT_A]; }
void ndos_quicc_play_clear(uint8_t colour, uint32_t workers) { qp_setup(0,0,319,199,colour,workers); qp[QP_COMMAND]=QP_CLEAR; }
void ndos_quicc_play_fill_rect(uint16_t x0,uint16_t y0,uint16_t x1,uint16_t y1,uint8_t colour,uint32_t workers) { qp_setup(x0,y0,x1,y1,colour,workers); qp[QP_COMMAND]=QP_FILL_RECT; }
void ndos_quicc_play_line(uint16_t x0,uint16_t y0,uint16_t x1,uint16_t y1,uint8_t colour,uint32_t workers) { qp_setup(x0,y0,x1,y1,colour,workers); qp[QP_COMMAND]=QP_LINE; }
void ndos_quicc_play_checkerboard(uint8_t colour,uint32_t workers) { qp_setup(0,0,319,199,colour,workers); qp[QP_COMMAND]=QP_CHECKERBOARD; }
