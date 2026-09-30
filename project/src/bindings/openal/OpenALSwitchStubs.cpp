// devkitPro's switch-openal portlib (openal-soft 1.21.1) doesn't implement the
// ALC_SOFT_events / ALC_SOFT_reopen_device extensions that lime's OpenALBindings.cpp
// unconditionally references (they're normally resolved via alcGetProcAddress at
// runtime, not direct linking, but lime links them directly). Nothing in this game's
// Haxe code calls lime.media.openal.ALC's event/reopen-device APIs, so these are
// inert stand-ins to satisfy the linker.
//
// Separately, libopenal.a itself was built with an SDL2-based backend prober
// (alc/backends/sdl2.cpp) compiled in - dead code since the switch build selects a
// native audio backend, never SDL2 - but its call to SDL_GetNumAudioDevices is still
// an unresolved reference at link time. Linking the real libSDL2.a would collide with
// libSDL3.a (SDL3 keeps most of SDL2's function names), so it gets an inert stub too.

#include <AL/al.h>
#include <AL/alc.h>
#include <AL/alext.h>

extern "C"
{
	ALCboolean ALC_APIENTRY alcReopenDeviceSOFT(ALCdevice *device, const ALCchar *deviceName, const ALCint *attribs)
	{
		return ALC_FALSE;
	}

	ALCboolean ALC_APIENTRY alcEventControlSOFT(ALCsizei count, const ALCenum *events, ALCboolean enable)
	{
		return ALC_FALSE;
	}

	void ALC_APIENTRY alcEventCallbackSOFT(ALCEVENTPROCTYPESOFT callback, void *userParam)
	{
	}

	int SDL_GetNumAudioDevices(int iscapture)
	{
		return 0;
	}
}
