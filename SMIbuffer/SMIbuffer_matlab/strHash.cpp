#include "strHash.h"


namespace detail {
    namespace rt {
#define DO1(buf) crc = crc_table[((int)crc ^ (*buf++)) & 0xff] ^ (crc >> 8);
#define DO2(buf)  DO1(buf); DO1(buf);
#define DO4(buf)  DO2(buf); DO2(buf);
#define DO8(buf)  DO4(buf); DO4(buf);

        uint32_t crc32(const char * str, size_t len)
        {
            uint32_t crc = 0;
            if (str == nullptr)
                return crc;
            crc = crc ^ 0xFFFFFFFF;
            while (len >= 8)
            {
                DO8(str);
                len -= 8;
            }
            if (len)
            {
                do {
                    DO1(str);
                } while (--len);
            }
            return crc ^ 0xFFFFFFFF;
        }


    }
} //namespace detail

namespace rt {
    uint32_t crc32(const char * str, size_t len) {
        return detail::rt::crc32(str, len);
    }
}