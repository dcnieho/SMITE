#include "UDPMultiCast/utils.h"
#include "G_User.h"
//#include <ntstatus.h>

// to solve linker error of G_Lib.lib, which is compiled with older MSVC
// not sure this would actually work if any of these functions are needed!
extern "C" { FILE __iob_func[3] = { *stdin,*stdout,*stderr }; }


namespace {
    typedef int64_t (*fpGetTimeStamp) (void);
    fpGetTimeStamp getTimeFun = nullptr;
    
    // filetime to UNIX epoch
    int64_t ftimeToUNIX(int64_t ftime)
    {
        // Windows file times are in 100s of nanoseconds.
        // Convert to microseconds by dividing by 10.
        // Make sure its a rounding division, by applying int i = (x + (n / 2)) / n;

        // Then convert to Unix epoch:
        // Between January 1, 1601 and January 1, 1970, there were 369 complete years,
        // of which 89 were leap years (1700, 1800, and 1900 were not leap years).
        // That is a total of 134774 days, which is 11644473600 seconds.
        return (ftime+5) / 10 - 11644473600 * 1000 * 1000;
    }
    int64_t ftimeToUNIX(FILETIME ftime)
    {
        return ftimeToUNIX((static_cast<int64_t>(ftime.dwHighDateTime) << 32) | ftime.dwLowDateTime);
    }

    // get with windows timestamp project code
    int64_t getTimeStampWTP()
    {
        TimeStamp_TYPE TimeStamp;
        GetTimeStamp(&TimeStamp);
        return ftimeToUNIX(TimeStamp.Time);
    }

    // dynamic load GetSystemTimePreciseAsFileTime as we may be running on a platform that doesn't have it
    typedef WINBASEAPI VOID(WINAPI *fpGetSystemTimePreciseAsFileTime)(_Out_ LPFILETIME);
    fpGetSystemTimePreciseAsFileTime GetPreciseTime = nullptr;
    int64_t getTimeStampGetSystemTimePreciseAsFileTime()
    {
        FILETIME ft;
        GetPreciseTime(&ft);
        return ftimeToUNIX(ft);
    }

    int64_t getTimeStampGetSystemTimeAsFileTime()
    {
        FILETIME ft;
        GetSystemTimeAsFileTime(&ft);
        return ftimeToUNIX(ft);
    }
    
    void setMaxClockResolution()
    {
        // set system timer to highest resolution possible
        HINSTANCE hLibrary = LoadLibraryW(L"NTDLL.dll");
        typedef HRESULT(NTAPI* pSetTimerResolution)(ULONG RequestedResolution, BOOLEAN Set, PULONG ActualResolution);
        typedef HRESULT(NTAPI* pQueryTimerResolution)(PULONG MinimumResolution, PULONG MaximumResolution, PULONG CurrentResolution);

        ULONG minResolution, maxResolution, actualResolution;
        ((pQueryTimerResolution)GetProcAddress(hLibrary, "NtQueryTimerResolution"))(&minResolution, &maxResolution, &actualResolution);
        ((pSetTimerResolution)GetProcAddress(hLibrary, "NtSetTimerResolution"))(maxResolution, TRUE, &actualResolution);
        fprintf(stdout, "system timer set to resolution: %d\n", actualResolution);
    }
}


namespace timeUtils {
    // if WTP==true, try and use Windows Timestamp Project code, else use Windows native calls
    void initTimeStamping(bool setMaxClockRes /*= true*/, bool WTP /*= true*/)
    {
        if (setMaxClockRes)
            setMaxClockResolution();

        if (WTP)
        {
            TimeStamp_TYPE TimeStamp;
            // check the state of G_Kernel.exe without even initializing the pipe services :
            ::GetTimeStamp(&TimeStamp);
            while (TimeStamp.State < TIME_STAMP_CALIBRATED) {
                // G_Kernel time service is not calibrated
                switch (TimeStamp.State) {
                case TIME_STAMP_OFFLINE:
                    fprintf(stdout, "G_Kernel.exe is not running, please start G_Kernel.exe\n");
                    break;
                case TIME_STAMP_AWAITING_CALIBRATION:
                    fprintf(stdout, "G_Kernel.exe has not yet established calibration, please wait...\n");
                    break;
                }
                Sleep(1000);
                GetTimeStamp(&TimeStamp);
            }
            if (TimeStamp.State == TIME_STAMP_LICENSE_EXPIRED) fprintf(stdout, "License expired for G_Kernel.exe, continuing at default accuracy...\n");
            else fprintf(stdout, "G_Kernel.exe has established calibration, continuing...\n");

            // done, assign function pointer
            getTimeFun = &getTimeStampWTP;
        }
        else
        {
            if (IsWindows8OrGreater())
            {
                HMODULE hMod = GetModuleHandleW(L"kernel32");
                GetPreciseTime = (fpGetSystemTimePreciseAsFileTime)GetProcAddress(hMod, "GetSystemTimePreciseAsFileTime");
                getTimeFun = &getTimeStampGetSystemTimePreciseAsFileTime;
            }
            else
                getTimeFun = &getTimeStampGetSystemTimeAsFileTime;
        }
    }

    int64_t getTimeStamp()	// signed so we don't get in trouble if user does calculations with output that yield negative numbers
    {
        return getTimeFun ? getTimeFun() : 0;
    }
}
