/**
 * @brief ToaruOS audio module for Doom
 */
#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>

#include "deh_str.h"
#include "i_sound.h"
#include "i_system.h"
#include "i_swap.h"
#include "m_argv.h"
#include "m_misc.h"
#include "w_wad.h"
#include "z_zone.h"

#include "doomtype.h"

#ifdef __toaru__

static boolean use_sfx_prefix = false;

#define SAMPLE_COUNT 64 /* How many samples to send in a batch */
#define MAX_CHANNELS 32 /* How many DSP connections we want to have. How many sounds can Doom play at once anyway? */

struct mixerChannel {
	int fd;        /* File descriptor for this channel's DSP connection */
	int16_t * buf; /* Pointer to head of buffer for later freeing */
	int16_t * ptr; /* Current offset in sample buffer. */
	size_t len;    /* Remaining samples */
	int vol;       /* Current channel volume (0~255) */
	int sep;       /* Current channel separation (0~255) */
};

struct mixerChannel mix_channels[MAX_CHANNELS] = {0};

static void GetSfxLumpName(sfxinfo_t *sfx, char *buf, size_t buf_len) {
	if (sfx->link != NULL) {
		sfx = sfx->link;
	}
	if (use_sfx_prefix) {
		M_snprintf(buf, buf_len, "ds%s", DEH_String(sfx->name));
	} else {
		M_StringCopy(buf, DEH_String(sfx->name), buf_len);
	}
}

static void I_Toaru_PrecacheSounds(sfxinfo_t *sounds, int num_sounds) {
	/* No-op */
}

static int I_Toaru_GetSfxLumpNum(sfxinfo_t *sfx) {
	char namebuf[9];
	GetSfxLumpName(sfx, namebuf, sizeof(namebuf));
	return W_GetNumForName(namebuf);
}

static void I_Toaru_UpdateSoundParams(int handle, int vol, int sep) {
	/* Update volume */
	if (handle < 1 || handle > MAX_CHANNELS) return;

	if (mix_channels[handle-1].fd != 0) {
		mix_channels[handle-1].vol = vol;
		mix_channels[handle-1].sep = sep;
	}
}

static int I_Toaru_StartSound(sfxinfo_t *sfxinfo, int channel, int vol, int sep) {
	int lumpnum;
	unsigned int lumplen;
	int samplerate;
	unsigned int length;
	byte *data;

	lumpnum = sfxinfo->lumpnum;
	data = W_CacheLumpNum(lumpnum, PU_STATIC);
	lumplen = W_LumpLength(lumpnum);

	if (lumplen < 8 || data[0] != 0x03 || data[1] != 0x00) {
		fprintf(stderr, "sound: invalid header\n");
		return false;
	}

	samplerate = (data[3] << 8) | data[2];
	length = (data[7] << 24) | (data[6] << 16) | (data[5] << 8) | data[4];

	if (length > lumplen - 8 || length <= 48) {
		fprintf(stderr, "sound: invalid length\n");
		return false;
	}

	data += 16;
	length -= 32;

	int spkr = open("/dev/dsp", O_WRONLY);
	if (spkr < 0) {
		return false;
	}

	ioctl(spkr, 4, NULL);

	/* Terrible sample rate conversion as our DSP always expected 48KHz */
	uint64_t expanded_length = ((uint64_t) length * 48000) / samplerate;
	int expand_ratio = (length << 8) / expanded_length;
	int16_t * snd = malloc(expanded_length * sizeof(int16_t));
	for (int i = 0; i < expanded_length; ++i) {
		int src = (i * expand_ratio) >> 8;
		int16_t sample = data[src] | (data[src] << 8);
		sample -= 32768;
		snd[i] = sample;
	}

	/* find an available channel */
	for (int i = 0; i < MAX_CHANNELS; ++i) {
		if (mix_channels[i].fd == 0) {
			mix_channels[i].fd = spkr;
			mix_channels[i].len = expanded_length;
			mix_channels[i].buf = snd;
			mix_channels[i].ptr = snd;
			mix_channels[i].vol = vol;
			mix_channels[i].sep = sep;
			return i+1;
		}
	}

	/* No available mixer channels, give up. */
	close(spkr);
	free(snd);
	return false;
}

static void I_Toaru_StopSound(int handle) {
	/* Stop playback */
	if (handle >= 1 && handle <= MAX_CHANNELS) {
		mix_channels[handle-1].len = 0;
	}
}

static boolean I_Toaru_SoundIsPlaying(int handle) {
	if (handle >= 1 && handle <= MAX_CHANNELS) {
		return (mix_channels[handle-1].fd != 0);
	}
	return false;
}

static int16_t tmp_samples[SAMPLE_COUNT * 2];
static void I_Toaru_UpdateSound(void) {
	for (int i = 0; i < MAX_CHANNELS; ++i) {
		if (mix_channels[i].fd == 0) continue;

		while (mix_channels[i].len) {
			int sample_count = mix_channels[i].len > SAMPLE_COUNT ? SAMPLE_COUNT : mix_channels[i].len;

			int left = ((254 - mix_channels[i].sep) * mix_channels[i].vol) / 127;
			int right = ((mix_channels[i].sep) * mix_channels[i].vol) / 127;

			for (int j = 0; j < sample_count; ++j) {
				tmp_samples[j*2]   = mix_channels[i].ptr[j] * left / 256;
				tmp_samples[j*2+1] = mix_channels[i].ptr[j] * right / 256;
			}

			ssize_t bytes = write(mix_channels[i].fd, tmp_samples, sizeof(int16_t) * sample_count * 2);
			if (bytes <= 0) break;
			mix_channels[i].ptr += bytes / 4;
			mix_channels[i].len -= bytes / 4;
		}

		if (mix_channels[i].len == 0) {
			close(mix_channels[i].fd);
			mix_channels[i].fd = 0;
			free(mix_channels[i].buf);
		}
	}
}

static void I_Toaru_ShutdownSound(void) {
	/* Supposed to shutdown */
}

static boolean I_Toaru_InitSound(boolean _use_sfx_prefix) {
	use_sfx_prefix = _use_sfx_prefix;
	fprintf(stderr, "toaru: init sound system\n");
	return true;
}

static snddevice_t sound_toaru_devices[] = {
	SNDDEVICE_SB,
	SNDDEVICE_PAS,
	SNDDEVICE_GUS,
	SNDDEVICE_WAVEBLASTER,
	SNDDEVICE_SOUNDCANVAS,
	SNDDEVICE_AWE32,
};

sound_module_t sound_toaru_module = {
	sound_toaru_devices,
	arrlen(sound_toaru_devices),
	I_Toaru_InitSound,
	I_Toaru_ShutdownSound,
	I_Toaru_GetSfxLumpNum,
	I_Toaru_UpdateSound,
	I_Toaru_UpdateSoundParams,
	I_Toaru_StartSound,
	I_Toaru_StopSound,
	I_Toaru_SoundIsPlaying,
	I_Toaru_PrecacheSounds,
};

#endif
