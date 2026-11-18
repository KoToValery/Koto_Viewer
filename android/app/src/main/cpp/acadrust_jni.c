#include <jni.h>
#include <stddef.h>
#include <stdint.h>
#include <unistd.h>

extern int32_t koto_acadrust_read_utf16(const uint16_t *input, size_t input_len, int32_t fd);
extern int32_t koto_acadrust_read_utf16_detailed(const uint16_t *input, size_t input_len,
                                               int32_t fd, uint8_t *error, size_t capacity);

JNIEXPORT jint JNICALL
Java_com_koto_kotoviewer_DwgConverterService_readDwgWithAcadrustDetailed(
    JNIEnv *env, jclass clazz, jstring input, jint output_fd, jbyteArray diagnostic) {
    (void)clazz;
    if (!input || output_fd < 0 || !diagnostic) return -1;
    const jchar *chars = (*env)->GetStringChars(env, input, NULL);
    if (!chars) return -1;
    jbyte *error = (*env)->GetByteArrayElements(env, diagnostic, NULL);
    if (!error) {
        (*env)->ReleaseStringChars(env, input, chars);
        return -1;
    }
    const int cloned_fd = dup(output_fd);
    const jint result = cloned_fd < 0 ? -1 : koto_acadrust_read_utf16_detailed(
        chars, (size_t)(*env)->GetStringLength(env, input), cloned_fd,
        (uint8_t *)error, (size_t)(*env)->GetArrayLength(env, diagnostic));
    (*env)->ReleaseByteArrayElements(env, diagnostic, error, 0);
    (*env)->ReleaseStringChars(env, input, chars);
    return result;
}

JNIEXPORT jint JNICALL
Java_com_koto_kotoviewer_DwgConverterService_readDwgWithAcadrust(
    JNIEnv *env, jclass clazz, jstring input, jint output_fd) {
    (void)clazz;
    if (!input || output_fd < 0) return -1;
    const jchar *chars = (*env)->GetStringChars(env, input, NULL);
    if (!chars) return -1;
    const int cloned_fd = dup(output_fd);
    const jint result = cloned_fd < 0 ? -1 : koto_acadrust_read_utf16(
        chars, (size_t)(*env)->GetStringLength(env, input), cloned_fd);
    (*env)->ReleaseStringChars(env, input, chars);
    return result;
}

extern int32_t koto_acadrust_convert_utf16(const uint16_t *input, size_t input_len,
                                         const uint16_t *output, size_t output_len);

JNIEXPORT jint JNICALL
Java_com_koto_kotoviewer_DwgConverterService_convertDwgWithAcadrust(
    JNIEnv *env, jclass clazz, jstring input, jstring output) {
    (void)clazz;
    if (!input || !output) return -1;
    const jchar *in_chars = (*env)->GetStringChars(env, input, NULL);
    if (!in_chars) return -1;
    const jchar *out_chars = (*env)->GetStringChars(env, output, NULL);
    if (!out_chars) {
        (*env)->ReleaseStringChars(env, input, in_chars);
        return -1;
    }
    const jint result = koto_acadrust_convert_utf16(
        in_chars, (size_t)(*env)->GetStringLength(env, input),
        out_chars, (size_t)(*env)->GetStringLength(env, output));
    (*env)->ReleaseStringChars(env, output, out_chars);
    (*env)->ReleaseStringChars(env, input, in_chars);
    return result;
}
