// libopenal.a itself was built with an SDL2-based backend prober
// (alc/backends/sdl2.cpp) compiled in - dead code since the switch build selects a
// native audio backend, never SDL2 - but its call to SDL_GetNumAudioDevices is still
// an unresolved reference at link time. Linking the real libSDL2.a would collide with
// libSDL3.a (SDL3 keeps most of SDL2's function names), so it gets an inert stub too.

#include <AL/al.h>
#include <AL/alc.h>
#include <AL/alext.h>

extern "C"
{
	int SDL_GetNumAudioDevices(int iscapture)
	{
		return 0;
	}

	int SDL_RenderCopy() { return -1; }
	int SDL_GetRenderDriverInfo() { return -1; }
	int SDL_GetRendererInfo() { return -1; }
	int SDL_RenderSetLogicalSize() { return -1; }
	int SDL_IsScreenSaverEnabled() { return 0; }
	int SDL_GetWindowDisplayIndex() { return -1; }
	void *SDL_GameControllerGetJoystick() { return 0; }
	int SDL_JoystickInstanceID() { return -1; }
	const char *SDL_GameControllerName() { return 0; }
	void SDL_GameControllerClose() {}
	int SDL_IsGameController() { return 0; }
	void *SDL_GameControllerOpen() { return 0; }
	void SDL_PauseAudio() {}
	void SDL_LockAudio() {}
	void SDL_UnlockAudio() {}
	void SDL_CloseAudio() {}
	int SDL_OpenAudio() { return -1; }
}
