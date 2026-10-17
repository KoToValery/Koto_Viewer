import 'dart:ffi';
import 'dart:io';

// A Flutter test process has no registered platform texture plugin. Keep unit
// tests deterministic; the Windows smoke application exercises the real engine.
bool get cad3dTextureSupported =>
    const bool.fromEnvironment('CAD_3D_GPU_ENABLED', defaultValue: true) &&
    Platform.environment['FLUTTER_TEST'] != 'true' &&
    (Platform.isWindows ||
        (Platform.isAndroid && Abi.current() == Abi.androidArm64));
