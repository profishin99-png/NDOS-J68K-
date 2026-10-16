#ifndef NDOS_INPUT_H
#define NDOS_INPUT_H
#include <stdint.h>
/* Temporary MAME host-keyboard ABI. Values are translated character bytes, not PS/2 scan codes. */
#define NDOS_INPUT_NO_DATA (-1)
int32_t ndos_input_get_char(void);
#endif