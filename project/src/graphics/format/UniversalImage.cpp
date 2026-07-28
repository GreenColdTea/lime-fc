#include <system/System.h>
#include <graphics/ImageBuffer.h>
#include <graphics/PixelFormat.h>
#include <graphics/format/UniversalImage.h>
#include <utils/Bytes.h>

#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>
#include <climits>

namespace lime {


    bool UniversalImage::Decode (Resource *resource, ImageBuffer *imageBuffer, const char* formatExt) {

        if (!resource) {
            return false;
        }

        SDL_IOStream *io = nullptr;

        if (resource->path) {
            io = SDL_IOFromFile (resource->path, "rb");
        } else if (resource->data) {
            io = SDL_IOFromConstMem (resource->data->b, resource->data->length);
        }

        if (!io) {
            return false;
        }

        SDL_Surface *surface = nullptr;
        
        if (formatExt) {
            surface = IMG_LoadTyped_IO (io, false, formatExt);
        } else {
            surface = IMG_Load_IO (io, false);
        }

        if (!surface && resource->path) {
            const char *ext = strrchr(resource->path, '.');
            if (ext) {
                SDL_SeekIO(io, 0, SDL_IO_SEEK_SET);
                surface = IMG_LoadTyped_IO (io, false, ext + 1);
            }
        }

        SDL_CloseIO(io);

        if (!surface) {
            return false;
        }

        if (surface->format != SDL_PIXELFORMAT_RGBA32) {
            SDL_Surface *old_surface = surface;
            surface = SDL_ConvertSurface (old_surface, SDL_PIXELFORMAT_RGBA32);
            SDL_DestroySurface (old_surface);
        }

        if (!surface) {
            return false;
        }

        imageBuffer->Resize (surface->w, surface->h, 32);
        
        if (surface->pitch == surface->w * 4) {
            memcpy (imageBuffer->data->buffer->b, surface->pixels, (size_t)(surface->h * surface->pitch));
        } else {
            for (int y = 0; y < surface->h; y++) {
                memcpy (imageBuffer->data->buffer->b + y * surface->w * 4, (uint8_t*)surface->pixels + y * surface->pitch, surface->w * 4);
            }
        }

        SDL_DestroySurface (surface);

        return true;
    }


    bool UniversalImage::Encode (ImageBuffer *imageBuffer, Bytes *bytes, int type, int quality) {
        if (!imageBuffer || !imageBuffer->data || !bytes) {
            return false;
        }

        int width = imageBuffer->width;
        int height = imageBuffer->height;
        
        int pitch = width * 4;
        SDL_Surface *surface = SDL_CreateSurfaceFrom(
            width, 
            height, 
            SDL_PIXELFORMAT_RGBA32, 
            imageBuffer->data->buffer->b, 
            pitch
        );

        if (!surface) {
            return false;
        }

        SDL_IOStream *io = SDL_IOFromDynamicMem();
        if (!io) {
            SDL_DestroySurface(surface);
            return false;
        }

        bool success = false;

        switch (type) {
            case 0: // PNG
                success = IMG_SavePNG_IO(surface, io, false);
                break;
            case 1: // JPEG
                success = IMG_SaveJPG_IO(surface, io, false, quality);
                break;
            case 2: // BMP
                success = IMG_SaveBMP_IO(surface, io, false);
                break;
            case 3: // WEBP
                success = IMG_SaveWEBP_IO(surface, io, false, (float)quality);
                break;
            case 4: // AVIF
                success = IMG_SaveAVIF_IO(surface, io, false, quality);
                break;
            case 5: // GIF
                success = IMG_SaveGIF_IO(surface, io, false);
                break;
            case 6: // TGA
                success = IMG_SaveTGA_IO(surface, io, false);
                break;
            case 7: // ICO
                success = IMG_SaveICO_IO(surface, io, false);
                break;
            case 8: // CUR
                success = IMG_SaveCUR_IO(surface, io, false);
                break;
            default: // Fallback on PNG
                success = IMG_SavePNG_IO(surface, io, false);
                break;
        }

        if (success) {
            Sint64 dataSize = SDL_GetIOSize(io);
            void *memData = SDL_GetPointerProperty(SDL_GetIOProperties(io), SDL_PROP_IOSTREAM_DYNAMIC_MEMORY_POINTER, nullptr);

            if (memData && dataSize > 0 && dataSize <= INT_MAX) {
                bytes->Resize((int)dataSize);
                memcpy(bytes->b, memData, (size_t)dataSize);
            } else {
                success = false;
            }
        }

        SDL_CloseIO(io);
        SDL_DestroySurface(surface);

        return success;
    }

}