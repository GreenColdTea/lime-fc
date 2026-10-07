#include <system/System.h>
#include <graphics/ImageBuffer.h>
#include <graphics/PixelFormat.h>
#include <graphics/format/UniversalImage.h>
#include <utils/Bytes.h>

#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>

#include <climits>
#include <thread>
#include <vector>
 
#if defined(_MSC_VER)
    #ifndef __attribute__
        #define __attribute__(x) 
    #endif
    #ifndef __deprecated__
        #define __deprecated__
    #endif
#endif

#ifndef __SWITCH__
#include <jxl/decode.h>
#include <jxl/thread_parallel_runner.h>
#endif

namespace lime {

    static bool DecodeAnimation_Stitched(SDL_IOStream* io, ImageBuffer* imageBuffer) {
        Sint64 start = SDL_TellIO(io);
        
        IMG_Animation* anim = IMG_LoadAnimation_IO(io, false);
        
        if (!anim || anim->count <= 1) {
            if (anim) IMG_FreeAnimation(anim);
            SDL_SeekIO(io, start, SDL_IO_SEEK_SET);
            return false;
        }

        int frame_w = anim->w;
        int frame_h = anim->h;
        int frame_count = anim->count;

        imageBuffer->Resize(frame_w * frame_count, frame_h, 32);
        imageBuffer->transparent = true;

        uint8_t* dest = imageBuffer->data->buffer->b;
        size_t row_stride = frame_w * 4;
        size_t total_stride = row_stride * frame_count;

        for (int f = 0; f < frame_count; ++f) {
            SDL_Surface* surface = anim->frames[f];
            SDL_Surface* rgba_surface = surface;
            
            if (surface->format != SDL_PIXELFORMAT_RGBA32) {
                rgba_surface = SDL_ConvertSurface(surface, SDL_PIXELFORMAT_RGBA32);
            }

            if (rgba_surface) {
                uint8_t* src_pixels = (uint8_t*)rgba_surface->pixels;
                int src_pitch = rgba_surface->pitch;

                for (int y = 0; y < frame_h; ++y) {
                    memcpy(dest + (y * total_stride) + (f * row_stride),
                           src_pixels + (y * src_pitch),
                           row_stride);
                }

                if (rgba_surface != surface) {
                    SDL_DestroySurface(rgba_surface);
                }
            }
        }

        IMG_FreeAnimation(anim);
        return true;
    }

    #ifndef __SWITCH__
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
        if (num_threads == 0) num_threads = 1;

        void* runner = JxlThreadParallelRunnerCreate(NULL, num_threads);
        if (runner) {
            JxlDecoderSetParallelRunner(dec, JxlThreadParallelRunner, runner);
        }

        JxlDecoderSetCoalescing(dec, JXL_TRUE);
        JxlDecoderSubscribeEvents(dec, JXL_DEC_BASIC_INFO | JXL_DEC_FRAME | JXL_DEC_FULL_IMAGE);
        JxlDecoderSetInput(dec, data, (size_t)dataSize);

        JxlBasicInfo info;
        JxlPixelFormat format = {4, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};

        std::vector<std::vector<uint8_t>> frames;
        std::vector<uint8_t> current_frame;
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
                
                current_frame.resize(buffer_size);
                if (JxlDecoderSetImageOutBuffer(dec, &format, current_frame.data(), buffer_size) != JXL_DEC_SUCCESS) break;
            } else if (status == JXL_DEC_FULL_IMAGE) {
                frames.push_back(current_frame);
                success = true; 
            } else if (status == JXL_DEC_SUCCESS) {
                break; 
            }
        }

        if (success && !frames.empty()) {
            size_t frame_count = frames.size();
            
            imageBuffer->Resize(info.xsize * frame_count, info.ysize, 32);
            imageBuffer->transparent = (info.alpha_bits > 0);

            uint8_t* dest = imageBuffer->data->buffer->b;
            size_t row_stride = info.xsize * 4;
            size_t total_stride = row_stride * frame_count;

            for (size_t f = 0; f < frame_count; ++f) {
                for (size_t y = 0; y < info.ysize; ++y) {
                    memcpy(dest + (y * total_stride) + (f * row_stride),
                           frames[f].data() + (y * row_stride),
                           row_stride);
                }
            }
        }

        if (runner) JxlThreadParallelRunnerDestroy(runner);
        JxlDecoderDestroy(dec);
        SDL_free(data);

        return success;
    }
    #endif

    bool UniversalImage::Decode (Resource *resource, ImageBuffer *imageBuffer, const char* formatExt) {

        if (!resource) return false;

        SDL_IOStream *io = nullptr;

        if (resource->path) {
            io = SDL_IOFromFile (resource->path, "rb");
        } else if (resource->data) {
            io = SDL_IOFromConstMem (resource->data->b, resource->data->length);
        }

        if (!io) return false;

        bool is_jxl = false;
        Sint64 start = SDL_TellIO(io);
        uint8_t magic[12];

        if (SDL_ReadIO(io, magic, 12) == 12) {
            #ifndef __SWITCH__
            if (magic[0] == 0xFF && magic[1] == 0x0A) {
                is_jxl = true; // Raw JXL stream
            } else if (magic[0] == 0x00 && magic[1] == 0x00 && magic[2] == 0x00 && magic[3] == 0x0C &&
                       magic[4] == 'J' && magic[5] == 'X' && magic[6] == 'L' && magic[7] == ' ') {
                is_jxl = true; // JXL container
            }
            #endif
        }
        SDL_SeekIO(io, start, SDL_IO_SEEK_SET);

        #ifndef __SWITCH__
        if (is_jxl) {
            bool result = DecodeJXL_Multithreaded(io, imageBuffer);
            SDL_CloseIO(io);
            return result;
        }
        #endif

        if (DecodeAnimation_Stitched(io, imageBuffer)) {
            SDL_CloseIO(io);
            return true;
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

        if (!surface) {
            SDL_SeekIO(io, start, SDL_IO_SEEK_SET);
            surface = IMG_LoadTyped_IO(io, false, "TGA");
        }

        SDL_CloseIO(io);

        if (!surface) return false;

        if (surface->format != SDL_PIXELFORMAT_RGBA32) {
            SDL_Surface *old_surface = surface;
            surface = SDL_ConvertSurface (old_surface, SDL_PIXELFORMAT_RGBA32);
            SDL_DestroySurface (old_surface);
        }

        if (!surface) return false;

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