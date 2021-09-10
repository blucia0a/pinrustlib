Building a Rust library that natively links to a pintool.
-----------------------------------------------------------------------------
Brandon Lucia 
September 10-12 2021

This project is an ongoing attempt to make a Rust library (either
static or shared/dynamic) that can be linked into a pintool
(https://pintool.org).  

The motivation behind this project was to allow development of an
architectural simulator written entirely in Rust that would consume
operations generated from analysis functions instrumented into an x86 binary
by Pin. 

There are several things that made this project more complex than it
initially seemed to be.  This README will serve as both informative and
narrative of the experiment and how it arrived at this apparently working
(albeit limited) point. 

The structure of this readme is in Attempts, which chronicle what does *not* work and why.

Attempt #1: Build a Rust shared library that links to a pintool without
-----------------------------------------------------------------------
thinking too hard about it.
-----------------------------------------------------------------------

This attempt entailed first writing a no-op runtime library in Rust that a
C/C++ program can natively refer to.  This process is well-documented (e.g.,
https://docs.rust-embedded.org/book/interoperability/rust-with-c.html).

The steps in this process are:

1)cargo new --lib rustlib
2)Edit Cargo.toml to include the following lines:

    [lib]
    crate_type = ["cdylib"] 

3)In lib.rs add the following lines, defining an un-mangled API function exposed by the Rust library:

    #[no_mangle]
    pub extern "C" fn rust_run() {/*Do some simulation stuff here*/}

4)Build the rust library (cargo build) and see that
target/debug/librustlib.so exists.  `nm librustlib.so` should report that
(among many other things) rust_run exists.


After building the Rust library, the next step in the process is to build the
pintool.  Building the pintool here happens in the usual way, except that the
makefile.rules for the pintool should be modified to add -lrustlib and
-L<path>/<to>/<librustlib> to the existing contents of the TOOL_LPATHS and
TOOL_LIBS variables.

At this point, it seemed like the process was successful!  Not so.

Mystery: librustlib.so "not found"
----------------------------------
Running the pintool reports that librustlib.so is not found by dlopen.  That
is usually the error when LD_LIBRARY_PATH incorrectly does not include the
path to a shared library that a program attempts to load.  In this instance, the library path was correct.  In fact, re-building the pintool and adding -Wl,-rpath,<path>/<to>/<librustlib> so that the pintool is built to always use the same path also fails with the same error.

After a lot of digging, I found that all libraries linked to any pintool must be linked to Pin's customized C runtime library (PinCRT) or nothing works.  The docs for this process are sparse and hard to find.  This thread helped (https://stackoverflow.com/questions/37707344/how-to-link-dramsim2-library-interface-with-a-pintool).  The PinCRT reference (https://software.intel.com/sites/landingpage/pintool/docs/98332/PinCRT/PinCRT.pdf) includes steps for building a library against PinCRT.  

The process is essentially to convince the library's makefile to produce a
command line similar to the build command line that runs when building a
pintool.  That command line includes lots of pin-specific include paths,
pre-processor directives, library paths, and libraries.  


Attempt #2: Build a C shared library that links to a pintool
------------------------------------------------------------
Using the PinCRT reference mentioned above, the next step was to forget about
Rust.  A good intermediate step was to try building any C shared library that
links to a pintool.  The steps in the PinCRT reference produce a library that
did not work correctly when linked to, and called from the pintool.  The
problem was either failing to dlopen ("not found" again) or to fail to find
the symbol (even when that symbol is properly marked extern "C" to avoid C++
name mangling).

A hack that is not good software engineering worked: a copy/paste of the pintool build command line with the library's source and output file swapped in built and loaded successfully in the pintool. 

This process confirms that building a shared library using the command line that the pintool uses when it builds produces a shared library that a pintool can load and call into.  The key here is that the library does not refer to any standard libraries, including and especially the native C runtime library.

Attempt #3: Build a Rust static library and try linking it to a C shared
------------------------------------------------------------------------
library that works for Pin
--------------------------
The process to build a Rust static library is similar to the one to build a
shared library (thanks to cargo for being easy to use).  The only change is
in Cargo.toml, replacing 


    [lib]
    crate_type = ["cdylib"]

with

    [lib]
    crate_type = ["staticlib"]

Running `$cargo build` produces librustlib.a in target/debug/.  Next, the C
shared library's Makefile is modified to include the -L path and -l flag for
the library and things build correctly.  

Unfortunately, this strategy also fails because the Rust static library
includes the Rust runtime, which refers to shared libraries, including the C
runtime library (not PinCRT).  Consequently, this option also fails,
producing a shared library that dlopen in the pintool fails to load ("not
found" again).

Attempt #4: Build a Rust static library and try linking it to a C static
------------------------------------------------------------------------
library that gets compiled directly into the pintool
----------------------------------------------------
This process entails building both libraries as static libraries and then
merging them together (i.e., the same as Attempt #3 for the Rust variant) and
the usual way using gcc for the C static library (i.e., running `ar rcs
liblibrary.a library.o` after compiling).  

With both static libraries in hand (librustlib.a and libpinlibtest.a), the next step is to merge them together.  This step happens using ar's ability to process an MRI librarian script (an apparent relic and esoteric mechanism).

The script is simple enough


    $cat libmerge.mri
    create librustlib.a
    addlib libpinlibtest.a
    addlib target/debug/librustlib.a
    save
    end 

and it gets invoked in the Makefile using ar's MRI script option:


    ar -M <libmerge.mri


The result of these commands is a single library in librustlib.a that
contains all of the code compiled into libpinlibtest.a and
target/debug/librustlib.a.

This seemed like it would almost work, but unfortunately fails again.  The
problem with this approach is that target/debug/librustlib.a also links to
the C standard library implementation that Rust uses.  

Attempt #5: Build a Rust static library without its own standard library and
------------------------------------------------------------------------
try linking it to a C static library that gets compiled directly into the
----------------------------------------------------
pintool
-------
This attempt was a partial success.  The goal this time was to build both of these libraries as static libraries, but to exclude the standard library from the rust part of the library.  The way to exclude Rust's standard library (which evidently also excludes Rust's C runtime) is to include 

    #![no_std]

at the top of your lib.rs.  Doing so has the side effect of erasing some
useful functionality from the crate.  To add that functionality back in
requires adding a few extra things to Cargo.toml and to your lib.rs. 
The minimal lib.rs that works with `#![no_std]` requires a code that does something when Rust panics and looks like this:
    
    #![no_std]

    use core::panic::PanicInfo;

    #[no_mangle]
    pub extern "C" fn rust_run(addr: i64) {

    }

    #[panic_handler]
    fn panic(_panic: &PanicInfo<'_>) -> ! {
        loop {}
    }

Cargo.toml needs a few additions, too, to tell the system what to do on panic:

    [profile.dev]
    panic = "abort"

    [profile.release]
    panic = "abort"

With this version linked together with the static C library, the pintool
builds!  In fact, the pintool even runs!  The code is written so that a
function in the C library calls a function in the Rust library.  The C
function can do whatever it wants and that seems to work correctly.  The 
C function can be made to call a Rust function and then things break again.
The error this time is that `bcmp()` is not found when loading the pintool.
This error is a weird one because Rust is not using the standard library and the C library should point to whatever memory manipulation functions are available in the Pin C runtime (i.e., if that means `bcmp()`, then it should be in PinCRT).

Rust gets compiled by LLVM and LLVM9 replaces some calls to `memcmp()` with
calls to `bcmp()`.  The `bcmp()` builtin is apparently deprecated and now may
not be available at runtime on some platforms (like PinCRT apparently).  The
problem is documented sporadically on the internet (e.g.:
https://github.com/rust-lang/compiler-builtins/issues/303).  The problem is
resolved by directly implementing `bcmp()` (e.g., from here:
https://opensource.apple.com/source/Libc/Libc-167/gen.subproj/i386.subproj/bcmp.c.auto.html).

A working pintool linked to a Rust runtime
==========================================
The result at this point is a working pintool that calls into a Rust library
via a C library built with the PinCRT.  It may be possible to eliminate the C
library that builds with PinCRT and directly link the no_std Rust library to
the pintool.  The Makefile situation for building the C library also needs to
improve, because right now it is a direct copy-paste job that needs manual
patching for each new system on which this project is built.

The no_std Rust library faces some limitations and is essentially like
programming for an embedded platform, like here: https://docs.rust-embedded.org/book/.

This toy example is intended to be a jumping off point for others interested
in building pintools using Rust.  Hopefully this whole project gets less
complicated and more useful with time.
