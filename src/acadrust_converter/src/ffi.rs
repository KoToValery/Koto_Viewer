use std::{panic, path::Path, slice, thread};

#[cfg(target_os = "android")]
#[no_mangle]
pub unsafe extern "C" fn koto_acadrust_read_utf16(input: *const u16, len: usize, fd: i32) -> i32 {
    use std::{fs::File, io::BufWriter, os::fd::FromRawFd};
    if fd < 0 { return -1; }
    let output = unsafe { File::from_raw_fd(fd) };
    if input.is_null() || len == 0 || len > 32768 { return -1; }
    panic::catch_unwind(|| {
        let path = match String::from_utf16(unsafe { slice::from_raw_parts(input, len) }) {
            Ok(value) if !value.contains('\0') => value,
            _ => return -2,
        };
        match thread::Builder::new().name("acadrust-read".into()).stack_size(8 * 1024 * 1024).spawn(move || {
            match crate::read_to_writer(Path::new(&path), BufWriter::new(output)) {
                Ok(()) => 0,
                Err(error) => { eprintln!("DWG read failed: {error}"); -3 }
            }
        }) {
            Ok(worker) => worker.join().unwrap_or(-4),
            Err(_) => -5,
        }
    }).unwrap_or(-4)
}

/// Android JNI supplies real UTF-16, avoiding JNI Modified UTF-8 for filenames
/// containing supplementary Unicode characters. Never unwind across JNI/C.
///
/// # Safety
/// Both pointers must refer to readable UTF-16 arrays of the supplied lengths
/// for the duration of this call. The JNI wrapper holds them until we return.
#[no_mangle]
pub unsafe extern "C" fn koto_acadrust_convert_utf16(
    input: *const u16,
    input_len: usize,
    output: *const u16,
    output_len: usize,
) -> i32 {
    if input.is_null()
        || output.is_null()
        || input_len == 0
        || output_len == 0
        || input_len > 32768
        || output_len > 32768
    {
        return -1;
    }
    panic::catch_unwind(|| {
        let input = match String::from_utf16(unsafe { slice::from_raw_parts(input, input_len) }) {
            Ok(path) if !path.contains('\0') => path,
            _ => return -2,
        };
        let output = match String::from_utf16(unsafe { slice::from_raw_parts(output, output_len) })
        {
            Ok(path) if !path.contains('\0') => path,
            _ => return -2,
        };
        // Decoding deeply nested blocks must not depend on the Java/Dart stack.
        match thread::Builder::new()
            .name("acadrust-dwg".into())
            .stack_size(8 * 1024 * 1024)
            .spawn(
                move || match crate::convert(Path::new(&input), Path::new(&output)) {
                    Ok(()) => 0,
                    Err(error) => {
                        eprintln!("acadrust DWG conversion failed: {error}");
                        -3
                    }
                },
            ) {
            Ok(worker) => worker.join().unwrap_or(-4),
            Err(_) => -5,
        }
    })
    .unwrap_or(-4)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_null_empty_and_invalid_utf16_paths() {
        let valid: Vec<u16> = "file.dwg".encode_utf16().collect();
        let invalid = [0xD800];
        let nul = [0];
        unsafe {
            assert_eq!(
                koto_acadrust_convert_utf16(std::ptr::null(), 1, valid.as_ptr(), valid.len()),
                -1
            );
            assert_eq!(
                koto_acadrust_convert_utf16(valid.as_ptr(), 0, valid.as_ptr(), valid.len()),
                -1
            );
            assert_eq!(
                koto_acadrust_convert_utf16(invalid.as_ptr(), 1, valid.as_ptr(), valid.len()),
                -2
            );
            assert_eq!(
                koto_acadrust_convert_utf16(nul.as_ptr(), 1, valid.as_ptr(), valid.len()),
                -2
            );
        }
    }
}
