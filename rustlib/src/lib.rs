#![no_std]
#![no_builtins]

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn rust_run(addr: i64) -> i64{
  addr+1
}

#[panic_handler]
fn panic(_panic: &PanicInfo<'_>) -> ! {
    loop {}
}
