use std::{env, io::BufWriter, path::Path, process::ExitCode};

fn main() -> ExitCode {
    let args: Vec<_> = env::args_os().skip(1).collect();
    if args.len() == 1 && args[0] == "--write-dwg" {
        return match koto_acadrust::write_dwg(std::io::stdin().lock(), std::io::stdout().lock()) {
            Ok(()) => ExitCode::SUCCESS,
            Err(error) => { eprintln!("DWG export failed: {error}"); ExitCode::FAILURE }
        };
    }
    if args.len() == 2 && args[0] == "--read" {
        let stdout = std::io::stdout();
        let output = BufWriter::with_capacity(64 * 1024, stdout.lock());
        return match koto_acadrust::read_to_writer(Path::new(&args[1]), output) {
            Ok(()) => ExitCode::SUCCESS,
            Err(error) => { eprintln!("DWG read failed: {error}"); ExitCode::FAILURE }
        };
    }
    if args.len() == 1 && args[0] == "--version" {
        println!(
            "koto-acadrust {} (acadrust {})",
            env!("CARGO_PKG_VERSION"),
            acadrust::VERSION
        );
        return ExitCode::SUCCESS;
    }
    if args.len() != 2 {
        eprintln!("Usage: koto-acadrust <input.dwg> <output.dxf>");
        return ExitCode::from(2);
    }
    match koto_acadrust::convert(Path::new(&args[0]), Path::new(&args[1])) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("DWG conversion failed: {error}");
            ExitCode::FAILURE
        }
    }
}
