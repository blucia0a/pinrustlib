all: librustlib.a

TARGET=intel64
XED_ARCH=intel64
BIONIC_ARCH=x86_64
CFLAGS= -D__PIN__=1 -DPIN_CRT=1 -DTARGET_IA32E -DHOST_IA32E -DTARGET_LINUX -funwind-tables -fasynchronous-unwind-tables -fomit-frame-pointer -fno-strict-aliasing -fno-exceptions -fno-rtti -fPIC -faligned-new 
INCLUDE=-isystem $(PIN_ROOT)/extras/stlport/include \
	-isystem $(PIN_ROOT)/extras/libstdc++/include \
	-isystem $(PIN_ROOT)/extras/crt/include \
	-isystem $(PIN_ROOT)/extras/crt/include/arch-$(BIONIC_ARCH) \
	-isystem $(PIN_ROOT)/extras/crt/include/kernel/uapi \
	-isystem $(PIN_ROOT)/extras/crt/include/kernel/uapi/asm-x86 \
	-I$(PIN_ROOT)/source/include/pin \
	-I$(PIN_ROOT)/source/include/pin/gen \
	-I$(PIN_ROOT)/extras/components/include \
	-I$(PIN_ROOT)/extras/xed-$(XED_ARCH)/include/xed
LDFLAGS=-nostdlib -lc-dynamic -lm-dynamic -lstlport-dynamic -L$(PIN_ROOT)/$(TARGET)/runtime/pincrt
CRT_BEGIN=$(PIN_ROOT)/$(TARGET)/runtime/pincrt/crtbeginS.o
CRT_END  =$(PIN_ROOT)/$(TARGET)/runtime/pincrt/crtendS.o

libpinlibtest.o: libpinlibtest.c
	g++ -c $(CFLAGS) $(INCLUDE) -o libpinlibtest.o -g libpinlibtest.c

libpinlibtest.a: libpinlibtest.o
	ar rcs libpinlibtest.a libpinlibtest.o

librustlib.a: libpinlibtest.a rustlib/target/debug/librustlib.a
	ar -M <libmerge.mri

libpinlibtest.so: libpinlibtest.o
	#g++ -shared -fPIC $(LDFLAGS) -o libpinlibtest.so $(CRT_BEGIN) libpinlibtest.o $(CRT_END)
	g++ -shared -Wl,--hash-style=sysv /home/blucia/cvsandbox/pin/pin-3.18-98332-gaebd7b1e6-gcc-linux/intel64/runtime/pincrt/crtbeginS.o -Wl,-Bsymbolic -Wl,--version-script=/home/blucia/cvsandbox/pin/pin-3.18-98332-gaebd7b1e6-gcc-linux/source/include/pin/pintool.ver -fabi-version=2    -o libpinlibtest.so libpinlibtest.o  -L/home/blucia/cvsandbox/pin/pin-3.18-98332-gaebd7b1e6-gcc-linux/intel64/runtime/pincrt -L/home/blucia/cvsandbox/pin/pin-3.18-98332-gaebd7b1e6-gcc-linux/intel64/lib -L/home/blucia/cvsandbox/pin/pin-3.18-98332-gaebd7b1e6-gcc-linux/intel64/lib-ext -L/home/blucia/cvsandbox/pin/pin-3.18-98332-gaebd7b1e6-gcc-linux/extras/xed-intel64/lib  -lpin -lxed /home/blucia/cvsandbox/pin/pin-3.18-98332-gaebd7b1e6-gcc-linux/intel64/runtime/pincrt/crtendS.o -lpin3dwarf  -ldl-dynamic -nostdlib -lstlport-dynamic -lm-dynamic -lc-dynamic -lunwind-dynamic 

clean:
	-rm libpinlibtest.so
	-rm libpinlibtest.o
	-rm libpinlibtest.a
	-rm librustlib.a
