import sys;
if sys.maxsize > 2**32:
    # running on 64bit platform
    from x64.SMIbuffer_python import *
else:
    # running on 32bit platform
    from x86.SMIbuffer_python import *