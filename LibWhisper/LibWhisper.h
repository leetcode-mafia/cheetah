#import <Foundation/Foundation.h>

//! Project version number for LibWhisper.
FOUNDATION_EXPORT double LibWhisperVersionNumber;

//! Project version string for LibWhisper.
FOUNDATION_EXPORT const unsigned char LibWhisperVersionString[];

// SDL functions used in CaptureDevice
#define SDL_INIT_AUDIO 0x00000010u
extern int SDL_Init(uint32_t flags);
extern int SDL_GetNumAudioDevices(int iscapture);
extern const char * SDL_GetAudioDeviceName(int index, int iscapture);

#import "stream.h"
