the import library provided by SMI contains the wrong dll name (iViewXAPI.dll, not iViewXAPI64.dll), so any application linked against this import lib will fail to load due to missing dll. This can happen if you manually rename the dll, for instance.

I have created a new import lib with the correct dll name to fix this.

Steps:
1. start a visual studio command prompt
2. dump exported function names:
dumpbin /exports "C:\Program Files (x86)\SMI\iView X SDK\bin\iViewXAPI64.dll" > temp.txt
3. create a def file from that info, creating what is in the folder here by using the name and ordinal columns of dumpbin's output
4. use that def file to create a new import library:
lib /MACHINE:x64 /def:iViewXAPI64.def
5. optionally place the file in C:\Program Files (x86)\SMI\iView X SDK\lib, if you're compiling against it