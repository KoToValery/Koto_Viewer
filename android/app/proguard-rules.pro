# Flutter ProGuard / R8 rules for Release Builds

# ML Kit Text Recognition optional language pack dependencies
-dontwarn com.google.mlkit.vision.text.**

# Keep native methods if any JNI is used
-keepclasseswithmembernames class * {
    native <methods>;
}

