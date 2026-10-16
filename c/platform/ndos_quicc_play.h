#ifndef NDOS_QUICC_PLAY_H
#define NDOS_QUICC_PLAY_H

/*
 * EXPERIMENTAL / MAME-only dual-M68000 graphics playground.
 *
 * This is not an MC68360 register map, ISA device, CPLD2 contract, or
 * physical J68K hardware plan.  It exists only for graphics experiments.
 */
#include <stdint.h>

#define NDOS_QUICC_PLAY_LEFT_WORKER  UINT32_C(0x01)
#define NDOS_QUICC_PLAY_RIGHT_WORKER UINT32_C(0x02)
#define NDOS_QUICC_PLAY_BOTH_WORKERS (NDOS_QUICC_PLAY_LEFT_WORKER | NDOS_QUICC_PLAY_RIGHT_WORKER)

uint32_t ndos_quicc_play_status(void);
uint32_t ndos_quicc_play_command_count(void);
uint32_t ndos_quicc_play_heartbeat(unsigned worker);
void ndos_quicc_play_clear(uint8_t colour, uint32_t workers);
void ndos_quicc_play_fill_rect(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint8_t colour, uint32_t workers);
void ndos_quicc_play_line(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint8_t colour, uint32_t workers);
void ndos_quicc_play_checkerboard(uint8_t colour, uint32_t workers);

#endif
