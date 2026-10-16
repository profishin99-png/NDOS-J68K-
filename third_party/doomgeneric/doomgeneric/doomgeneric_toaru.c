#include "doomkeys.h"

#include "doomgeneric.h"

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>

#include <toaru/yutani.h>
#include <toaru/graphics.h>
#include <toaru/decorations.h>
#include <toaru/spinlock.h>
#include <toaru/menu.h>

#undef __DOOMKEYS__
#undef KEY_BACKSPACE
#undef KEY_PAUSE
#undef KEY_HOME
#undef KEY_DEL
#undef KEY_F1
#undef KEY_END
#undef KEY_F2
#undef KEY_F3
#undef KEY_F4
#undef KEY_F5
#undef KEY_F6
#undef KEY_F7
#undef KEY_F8
#undef KEY_F9
#undef KEY_F10
#undef KEY_F11
#undef KEY_F12
#include "doomkeys.h"

static yutani_t * yctx;
static yutani_window_t * wina;
static gfx_context_t * ctx;
static char * wintitle = NULL;

#define KEYQUEUE_SIZE 512

static unsigned short s_KeyQueue[KEYQUEUE_SIZE];
static unsigned int s_KeyQueueWriteIndex = 0;
static unsigned int s_KeyQueueReadIndex = 0;

static unsigned char convertToDoomKey(unsigned int key) {
	switch (key) {
		/* These must be mapped because our values differ */
		case 8:   return KEY_BACKSPACE;
		case 257: return KEY_UPARROW;
		case 258: return KEY_DOWNARROW;
		case 260: return KEY_LEFTARROW;
		case 259: return KEY_RIGHTARROW;
		case '\n': return KEY_ENTER;

		/* Doom doesn't really care about these being left/right */
		case 1001: return KEY_FIRE; /* Make sure this is bound to FIRE correctly... */
		case 1011: return KEY_RCTRL;
		case 1002: return KEY_RSHIFT;
		case 1012: return KEY_RSHIFT;
		case 1003: return KEY_RALT;
		case 1013: return KEY_RALT;

		/* These are shortcuts in Doom */
		case 2001: return KEY_F1;
		case 2002: return KEY_F2;
		case 2003: return KEY_F3;
		case 2004: return KEY_F4;
		case 2005: return KEY_F5;
		case 2006: return KEY_F6;
		case 2007: return KEY_F7;
		case 2008: return KEY_F8;
		case 2009: return KEY_F9;
		case 2010: return KEY_F10;
		case 2011: return KEY_F11;
		case 2012: return KEY_F12;

		/* I think these just map to regular keys */
		case 2500: return KEYP_0;
		case 2501: return KEYP_1;
		case 2502: return KEYP_2;
		case 2503: return KEYP_3;
		case 2504: return KEYP_4;
		case 2505: return KEYP_5;
		case 2506: return KEYP_6;
		case 2507: return KEYP_7;
		case 2508: return KEYP_8;
		case 2509: return KEYP_9;
		case 2510: return KEYP_PERIOD;
		case 2511: return KEYP_DIVIDE;
		case 2512: return KEYP_MULTIPLY;
		case 2513: return KEYP_MINUS;
		case 2514: return KEYP_PLUS;
		case 2515: return KEYP_ENTER;
	}

	return key;
}

static void addKeyToQueue(int pressed, unsigned int keyCode) {
	unsigned char key = convertToDoomKey(keyCode);

	unsigned short keyData = (pressed << 8) | key;

	s_KeyQueue[s_KeyQueueWriteIndex] = keyData;
	s_KeyQueueWriteIndex++;
	s_KeyQueueWriteIndex %= KEYQUEUE_SIZE;
}

void DG_Init() {
	memset(s_KeyQueue, 0, KEYQUEUE_SIZE * sizeof(unsigned short));

	/* Force WASD keybinds */
	extern int key_strafeleft, key_straferight, key_up, key_down, key_use;

	key_strafeleft = 'a';
	key_straferight = 'd';
	key_up = 'w';
	key_down = 's';
	key_use = ' ';

	yctx = yutani_init();
	if (!yctx) {
		fprintf(stderr, "doomgeneric: failed to connect to compositor\n");
		exit(1);
	}

	init_decorations();
	struct decor_bounds bounds;
	decor_get_bounds(NULL, &bounds);

	wina = yutani_window_create(yctx, DOOMGENERIC_RESX + bounds.width, DOOMGENERIC_RESY + bounds.height);
	yutani_window_move(yctx, wina, 300, 300);
	ctx = init_graphics_yutani_double_buffer(wina);
	yutani_window_advertise_icon(yctx, wina, "Doom", "doom");

}


void DG_DrawFrame() {
	struct decor_bounds bounds;
	decor_get_bounds(wina, &bounds);

	if (wina->width - bounds.width == DOOMGENERIC_RESX) {
		for (int y = 0; y < DOOMGENERIC_RESY; ++y) {
			for (int x = 0; x < DOOMGENERIC_RESX; ++x) {
				unsigned int pixel = DG_ScreenBuffer[y * DOOMGENERIC_RESX + x];
				GFX(ctx,x+bounds.left_width,y+bounds.top_height) = pixel | rgba(0,0,0,255);
			}
		}
	} else {
		int my_width  = wina->width - bounds.width;
		int my_height = wina->height - bounds.height;
		for (int y = 0; y < my_height; ++y) {
			int this_y = y * DOOMGENERIC_RESY / my_height;
			for (int x = 0; x < my_width; ++x) {
				int this_x = x * DOOMGENERIC_RESX / my_width;
				unsigned int pixel = DG_ScreenBuffer[this_y * DOOMGENERIC_RESX + this_x];
				GFX(ctx,x+bounds.left_width,y+bounds.top_height) = pixel | rgba(0,0,0,255);
			}
		}
	}

	render_decorations(wina, ctx, wintitle ? wintitle : "Doom");
	flip(ctx);
	yutani_flip(yctx, wina);

	/* Get window events */
	yutani_msg_t * m = yutani_poll_async(yctx);
	while (m) {
		menu_process_event(yctx, m);
		switch (m->type) {
			case YUTANI_MSG_KEY_EVENT:
				{
					struct yutani_msg_key_event * ke = (void*)m->data;
					if (ke->wid == wina->wid) {
						addKeyToQueue(ke->event.action == KEY_ACTION_DOWN, ke->event.keycode);
					}
				}
				break;
			case YUTANI_MSG_WINDOW_FOCUS_CHANGE:
				{
					struct yutani_msg_window_focus_change * wf = (void*)m->data;
					if (wf->wid == wina->wid) {
						wina->focused = wf->focused;
					}
				}
				break;
			case YUTANI_MSG_WINDOW_CLOSE:
			case YUTANI_MSG_SESSION_END:
				exit(0);
				break;
			case YUTANI_MSG_WINDOW_MOUSE_EVENT:
				{
					struct yutani_msg_window_mouse_event * me = (void*)m->data;
					if (me->wid == wina->wid) {
						switch (decor_handle_event(yctx, m)) {
							case DECOR_CLOSE:
								exit(0);
								break;
							case DECOR_RIGHT:
								decor_show_default_menu(wina, wina->x + me->new_x, wina->y + me->new_y);
								break;
						}
					}
				}
				break;
			case YUTANI_MSG_RESIZE_OFFER:
				{
					struct yutani_msg_window_resize * wr = (void*)m->data;
					yutani_window_resize_accept(yctx, wina, wr->width, wr->height);
					reinit_graphics_yutani(ctx, wina);
					yutani_window_resize_done(yctx, wina);
				}
				break;
		}
		m = yutani_poll_async(yctx);
	}
}

void DG_SleepMs(uint32_t ms) {
	usleep (ms * 1000);
}

uint32_t DG_GetTicksMs() {
	struct timeval  tp;
	struct timezone tzp;
	gettimeofday(&tp, &tzp);
	return (tp.tv_sec * 1000) + (tp.tv_usec / 1000); /* return milliseconds */
}

int DG_GetKey(int* pressed, unsigned char* doomKey)
{
	/* Poll for keys */
	if (s_KeyQueueReadIndex == s_KeyQueueWriteIndex)
	{
		//key queue is empty

		return 0;
	}
	else
	{
		unsigned short keyData = s_KeyQueue[s_KeyQueueReadIndex];
		s_KeyQueueReadIndex++;
		s_KeyQueueReadIndex %= KEYQUEUE_SIZE;

		*pressed = keyData >> 8;
		*doomKey = keyData & 0xFF;

		return 1;
	}
}

void DG_SetWindowTitle(const char * title) {
	if (wintitle) free(wintitle);
	wintitle = strdup(title);
	yutani_window_advertise_icon(yctx, wina, wintitle, "doom");
}
