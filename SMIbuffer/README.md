The enclosed `.sln` file is to be opened and built with Visual Studio 2019 (tested with version 16.4.1).

## Dependencies
First some dependencies must be installed.

setup:
```
git clone https://github.com/Microsoft/vcpkg.git

cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install
```

for the Python wrapper, first install the PsychoPy version you want to work with. The below is for PsychoPy version 3.2.4, 64bit, Python 3.6.6. Furthermore using vcpkg commit `7a14422290e7583c68ee290f7dbb5d61872a7a99`. If your version of PsychoPy uses a different Python version, is installed in a different location, or the vcpkg port cmake file has changed, you may need to adapt the below accordingly.

1. Determine the location of PsychoPy. For me it is: `C:/Program Files/PsychoPy3` (note the forward slashes)
2. In your vcpkg directory, you need to edit some files.

   a. At `<vcpkg root>\ports\boost-python`, open the file `CONTROL`. Remove `, python3` from the `Build-Depends:` line. Save.
   
   b. At `<vcpkg root>\ports\boost-python`, open the file `portfile.cmake`. Apply the following patch
   ```diff
    )

    # Find Python. Can't use find_package here, but we already know where everything is
   -file(GLOB PYTHON_INCLUDE_PATH "${CURRENT_INSTALLED_DIR}/include/python[0-9.]*")
   -set(PYTHONLIBS_RELEASE "${CURRENT_INSTALLED_DIR}/lib")
   -set(PYTHONLIBS_DEBUG "${CURRENT_INSTALLED_DIR}/debug/lib")
   -string(REGEX REPLACE ".*python([0-9\.]+)$" "\\1" PYTHON_VERSION "${PYTHON_INCLUDE_PATH}")
   +set(PYTHON_INCLUDE_PATH "C:/Program Files/PsychoPy3/include")^M
   +set(PYTHONLIBS_RELEASE "C:/Program Files/PsychoPy3/Libs")^M
   +set(PYTHONLIBS_DEBUG "C:/Program Files/PsychoPy3/Libs")^M
   +set(PYTHON_VERSION "3.6")^M
    include(${CURRENT_INSTALLED_DIR}/share/boost-build/boost-modular-build.cmake)
    boost_modular_build(SOURCE_PATH ${SOURCE_PATH})
    include(${CURRENT_INSTALLED_DIR}/share/boost-vcpkg-helpers/boost-modular-headers.cmake)
   ```
   Save the file and close it.

3. Now you are ready to install boost-python, issue:
`vcpkg install boost-python:x64-windows`

## Environment variables
Furthermore, some environment variables must be set. Here are the values i used:
- `MATLAB_ROOT`: `C:\Program Files\MATLAB\R2019b`
- `MATLAB32_ROOT`: `C:\Program Files (x86)\MATLAB\R2019b`
- `PYTHON_ROOT`: `C:\Program Files\PsychoPy3`

## set up python environment for Visual Studio Python integration
Last, visual studio needs to be able to find your PsychoPy's Python environment. To do so, add a new Python environment, choose existing environment, and point it to the root of your PsychoPy install, in my case, `C:\Program Files\PsychoPy3`.
