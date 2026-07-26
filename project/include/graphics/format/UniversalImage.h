#ifndef LIME_GRAPHICS_FORMAT_UNIVERSALIMAGE_H
#define LIME_GRAPHICS_FORMAT_UNIVERSALIMAGE_H

#include <graphics/ImageBuffer.h>
#include <utils/Resource.h>

namespace lime {

    
    class UniversalImage {
        public:
            static bool Decode (Resource *resource, ImageBuffer *imageBuffer, const char* formatExt);

            static bool Encode (ImageBuffer *imageBuffer, Bytes *bytes, int type, int quality = 90);
    };

}

#endif