param(
    [string[]]$Abis = @('arm64-v8a', 'armeabi-v7a', 'x86_64'),
    [string]$SdkRoot,
    [string]$NdkVersion = '28.2.13676358',
    [int]$Api = 24
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $SdkRoot) {
    $sdkLine = Get-Content "$repoRoot/android/local.properties" | Where-Object { $_ -like 'sdk.dir=*' } | Select-Object -First 1
    if (-not $sdkLine) { throw 'Pass -SdkRoot or configure sdk.dir in android/local.properties.' }
    $SdkRoot = $sdkLine.Substring(8).Replace('\\', '\').Replace('\:', ':')
}
$cmakeBin = Join-Path $SdkRoot 'cmake/3.22.1/bin'
$ndkRoot = Join-Path $SdkRoot "ndk/$NdkVersion"
foreach ($abi in $Abis) {
    if ($abi -notin @('arm64-v8a', 'armeabi-v7a', 'x86_64')) { throw "Unsupported ABI: $abi" }
    $buildDir = Join-Path $repoRoot "build/acadrust/android-cmake/$abi"
    & "$cmakeBin/cmake.exe" -S "$repoRoot/android/app/src/main/cpp" -B $buildDir -G Ninja `
        "-DCMAKE_MAKE_PROGRAM=$cmakeBin/ninja.exe" `
        "-DCMAKE_TOOLCHAIN_FILE=$ndkRoot/build/cmake/android.toolchain.cmake" `
        "-DANDROID_ABI=$abi" "-DANDROID_PLATFORM=android-$Api" -DCMAKE_BUILD_TYPE=Release -DKOTO_REBUILD_ACADRUST=ON
    if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed for $abi" }
    & "$cmakeBin/cmake.exe" --build $buildDir --target koto_acadrust
    if ($LASTEXITCODE -ne 0) { throw "JNI build failed for $abi" }
}
