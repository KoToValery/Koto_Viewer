param([switch]$Test)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$localToolchain = Join-Path $repoRoot 'build/acadrust-toolchain'
$cargoCommand = Get-Command cargo -ErrorAction SilentlyContinue
if ($cargoCommand) {
    $cargoExe = $cargoCommand.Source
} elseif (Test-Path "$localToolchain/cargo/bin/cargo.exe") {
    $env:CARGO_HOME = "$localToolchain/cargo"
    $env:RUSTUP_HOME = "$localToolchain/rustup"
    $cargoExe = "$localToolchain/cargo/bin/cargo.exe"
} elseif (Test-Path "$env:USERPROFILE/.cargo/bin/cargo.exe") {
    $cargoExe = "$env:USERPROFILE/.cargo/bin/cargo.exe"
} else {
    throw 'Install Rust (MSVC toolchain) from https://rustup.rs, then run this script again.'
}
$env:PATH = "$(Split-Path -Parent $cargoExe);$env:PATH"
$cargoArgs = @(
    '--manifest-path', "$repoRoot/src/acadrust_converter/Cargo.toml",
    '--target-dir', "$repoRoot/build/acadrust",
    '--target', 'x86_64-pc-windows-msvc', '--locked'
)
if ($Test) {
    & $cargoExe test @cargoArgs
} else {
    & $cargoExe build --release @cargoArgs
}
if ($LASTEXITCODE -ne 0) { throw "Cargo failed with exit code $LASTEXITCODE" }
