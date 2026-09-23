#include <system/System.h>
#include <graphics/ImageBuffer.h>
#include <graphics/PixelFormat.h>
#include <graphics/format/UniversalImage.h>
#include <utils/Bytes.h>

#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>

#include <climits>
#include <thread>

#include <jxl/decode.h>
#include <jxl/thread_parallel_runner.h>

namespace lime {

    static bool DecodeJXL_Multithreaded(SDL_IOStream* io, ImageBuffer* imageBuffer) {
        Sint64 dataSize = SDL_GetIOSize(io);
        if (dataSize <= 0) return false;

        uint8_t* data = (uint8_t*)SDL_malloc((size_t)dataSize);
        if (!data) return false;
        
        SDL_SeekIO(io, 0, SDL_IO_SEEK_SET);
        if (SDL_ReadIO(io, data, (size_t)dataSize) != (size_t)dataSize) {
            SDL_free(data);
            return false;
        }

        JxlDecoder* dec = JxlDecoderCreate(NULL);
        if (!dec) {
            SDL_free(data);
            return false;
        }

        unsigned int num_threads = std::thread::hardware_concurrency();
        if (num_threads == 0) num_threads = 2;

        void* runner = JxlThreadParallelRunnerCreate(NULL, num_threads);
        if (runner) {
            JxlDecoderSetParallelRunner(dec, JxlThreadParallelRunner, runner);
        }

        JxlDecoderSubscribeEvents(dec, JXL_DEC_BASIC_INFO | JXL_DEC_FULL_IMAGE);
        JxlDecoderSetInput(dec, data, (size_t)dataSize);

        JxlBasicInfo info;
        JxlPixelFormat format = {4, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};

        bool success = false;

        for (;;) {
            JxlDecoderStatus status = JxlDecoderProcessInput(dec);

            if (status == JXL_DEC_ERROR || status == JXL_DEC_NEED_MORE_INPUT) {
                break;
            } else if (status == JXL_DEC_BASIC_INFO) {
                if (JxlDecoderGetBasicInfo(dec, &info) != JXL_DEC_SUCCESS) break;
            } else if (status == JXL_DEC_NEED_IMAGE_OUT_BUFFER) {
                size_t buffer_size;
                if (JxlDecoderImageOutBufferSize(dec, &format, &buffer_size) != JXL_DEC_SUCCESS) break;
                
                imageBuffer->Resize(info.xsize, info.ysize, 32);
                imageBuffer->transparent = (info.alpha_bits > 0);
                
                if (JxlDecoderSetImageOutBuffer(dec, &format, imageBuffer->data->buffer->b, buffer_size) != JXL_DEC_SUCCESS) break;
            } else if (status == JXL_DEC_FULL_IMAGE) {
                continue;
            } else if (status == JXL_DEC_SUCCESS) {
                success = true;
                break;
            } else {
                break; 
            }
        }

        if (runner) JxlThreadParallelRunnerDestroy(runner);
        JxlDecoderDestroy(dec);
        SDL_free(data);

        return success;
    }

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

        bool is_jxl = false;
        Sint64 start = SDL_TellIO(io);
        uint8_t magic[12];
        if (SDL_ReadIO(io, magic, 12) == 12) {
            if (magic[0] == 0xFF && magic[1] == 0x0A) {
                is_jxl = true; // Raw JXL stream
            } else if (magic[0] == 0x00 && magic[1] == 0x00 && magic[2] == 0x00 && magic[3] == 0x0C &&
                       magic[4] == 'J' && magic[5] == 'X' && magic[6] == 'L' && magic[7] == ' ') {
                is_jxl = true; // JXL container
            }
        }
        SDL_SeekIO(io, start, SDL_IO_SEEK_SET);

        if (is_jxl) {
            bool result = DecodeJXL_Multithreaded(io, imageBuffer);
            SDL_CloseIO(io);
            return result;
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