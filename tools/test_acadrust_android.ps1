param(
    [string]$Serial = 'emulator-5554',
    [string]$SdkRoot,
    [string]$JdkRoot
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $SdkRoot) {
    $line = Get-Content "$repoRoot/android/local.properties" | Where-Object { $_ -like 'sdk.dir=*' } | Select-Object -First 1
    if (-not $line) { throw 'Pass -SdkRoot or configure android/local.properties.' }
    $SdkRoot = $line.Substring(8).Replace('\\', '\').Replace('\:', ':')
}
if (-not $JdkRoot) {
    $localJdk = Get-ChildItem "$repoRoot/build/android-jdk" -Directory -ErrorAction SilentlyContinue |
        Where-Object Name -like 'jdk-*' | Select-Object -First 1
    $JdkRoot = if ($localJdk) { $localJdk.FullName } else { $env:JAVA_HOME }
}
if (-not (Test-Path "$JdkRoot/bin/javac.exe")) { throw 'Pass -JdkRoot with a JDK containing javac.' }
$adb = "$SdkRoot/platform-tools/adb.exe"
$abi = (& $adb -s $Serial shell getprop ro.product.cpu.abi).Trim()
if ($LASTEXITCODE -ne 0 -or $abi -notin @('arm64-v8a', 'armeabi-v7a', 'x86_64')) {
    throw 'Connect a supported Android device/emulator and pass its serial.'
}
$library = "$repoRoot/build/acadrust/android-cmake/$abi/libkoto_acadrust.so"
if (-not (Test-Path $library)) { throw "Build the $abi JNI library first." }
$testDir = "$repoRoot/build/acadrust/android-jni-test"
New-Item -ItemType Directory -Force -Path "$testDir/classes", "$testDir/dex" | Out-Null
& "$JdkRoot/bin/javac.exe" --release 8 -Xlint:-options -encoding UTF-8 -classpath "$SdkRoot/platforms/android-36/android.jar" -d "$testDir/classes" `
    "$repoRoot/tool/qa/android_acadrust/DwgConverterService.java"
if ($LASTEXITCODE -ne 0) { throw 'Java harness compilation failed.' }
$env:JAVA_HOME = $JdkRoot
& "$SdkRoot/build-tools/36.0.0/d8.bat" --min-api 24 --output "$testDir/dex" `
    "$testDir/classes/com/koto/kotoviewer/DwgConverterService.class"
if ($LASTEXITCODE -ne 0) { throw 'DEX generation failed.' }

# Unique dedicated directory, separate from all application and user files.
$remote = "/data/local/tmp/koto_acadrust_$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
& $adb -s $Serial shell mkdir -p "$remote/fixtures"
if ($LASTEXITCODE -ne 0) { throw 'Cannot create device test directory.' }
& $adb -s $Serial push $library "$remote/libkoto_acadrust.so"
if ($LASTEXITCODE -ne 0) { throw 'Cannot push JNI library.' }
& $adb -s $Serial push "$testDir/dex/classes.dex" "$remote/classes.dex"
if ($LASTEXITCODE -ne 0) { throw 'Cannot push DEX harness.' }
foreach ($fixture in Get-ChildItem "$repoRoot/test_files/*.dwg") {
    & $adb -s $Serial push $fixture.FullName "$remote/fixtures/$($fixture.Name)"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot push DWG fixture.' }
}
& $adb -s $Serial shell "CLASSPATH=$remote/classes.dex app_process /system/bin com.koto.kotoviewer.DwgConverterService $remote/libkoto_acadrust.so $remote/fixtures"
if ($LASTEXITCODE -ne 0) { throw 'Android JNI smoke test failed.' }
& $adb -s $Serial pull "$remote/fixtures/output" "$testDir/device-output"
if ($LASTEXITCODE -ne 0) { throw 'Cannot retrieve converted test drawings.' }
Write-Output "Android test artifacts: $remote and $testDir/device-output"
