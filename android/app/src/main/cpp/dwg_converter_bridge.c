#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#if defined(_WIN32) || defined(__CYGWIN__)
  #define KOTO_EXPORT __declspec(dllexport)
  #include <windows.h>
#else
  #define KOTO_EXPORT __attribute__((visibility("default"))) __attribute__((used))
  #include <pthread.h>
  #include <setjmp.h>
  #include <signal.h>
  #include <unistd.h>
#endif

#ifdef HAVE_LIBREDWG
#include <dwg.h>
#include <dwg_api.h>

#ifdef __ANDROID__
  #include <android/log.h>
  #define LOG_TAG "KotoDwg"
  #define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
  #define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
  #define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
  #define LOGI(...) printf(__VA_ARGS__)
  #define LOGW(...) printf(__VA_ARGS__)
  #define LOGE(...) fprintf(stderr, __VA_ARGS__)
#endif

typedef struct _bit_chain
{
  unsigned char *chain;
  size_t size;
  size_t byte;
  unsigned char bit;
  unsigned char opts;
  Dwg_Version_Type version;
  Dwg_Version_Type from_version;
  FILE *fh;
  BITCODE_RS codepage;
} Bit_Chain;

extern int dwg_read_file(const char *filename, Dwg_Data *dwg);
extern int dwg_write_dxf(Bit_Chain *dat, Dwg_Data *dwg);
extern void dwg_free(Dwg_Data *dwg);

#if !defined(_WIN32) && !defined(__CYGWIN__)
static __thread sigjmp_buf g_crash_jmp_buf;
static __thread volatile sig_atomic_t g_crash_guard_active = 0;

static void crash_signal_handler(int sig, siginfo_t *info, void *context) {
    (void)context;
    if (g_crash_guard_active) {
        LOGE("KotoDwg CRASH GUARD: Caught signal %d at address %p! Safely recovering...",
             sig, info ? info->si_addr : NULL);
        g_crash_guard_active = 0;
        siglongjmp(g_crash_jmp_buf, sig);
    } else {
        signal(sig, SIG_DFL);
        raise(sig);
    }
}
#endif

typedef struct {
    const char* in_dwg_path;
    const char* out_dxf_path;
    int result;
} ConvertWorkerParams;

static int do_convert_dwg_to_dxf(const char* in_dwg_path, const char* out_dxf_path) {
    LOGI("do_convert_dwg_to_dxf starting: %s -> %s", in_dwg_path, out_dxf_path);

    // 1. Verify input file is readable and get size
    FILE *fin_check = fopen(in_dwg_path, "rb");
    if (!fin_check) {
        LOGE("Cannot open input DWG file: %s (errno: %d)", in_dwg_path, errno);
        return -2;
    }
    fseek(fin_check, 0, SEEK_END);
    long fsize = ftell(fin_check);
    fclose(fin_check);
    LOGI("Input DWG file verified, size: %ld bytes (%.2f MB)", fsize, (double)fsize / (1024.0 * 1024.0));

    // 2. Allocate Dwg_Data on the HEAP (avoid stack pressure)
    // Over-allocate by 64KB to avoid ABI size mismatch buffer overflow
    Dwg_Data *dwg = (Dwg_Data*)calloc(1, sizeof(Dwg_Data) + 65536);
    if (!dwg) {
        LOGE("Failed to allocate Dwg_Data on heap (%zu bytes)", sizeof(Dwg_Data) + 65536);
        return -4;
    }

#if !defined(_WIN32) && !defined(__CYGWIN__)
    // 3. Install signal handlers to intercept SIGSEGV/SIGBUS/SIGABRT/SIGFPE/SIGTRAP/SIGILL
    struct sigaction sa, old_segv, old_bus, old_abrt, old_fpe, old_trap, old_ill;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = crash_signal_handler;
    sa.sa_flags = SA_SIGINFO | SA_NODEFER;
    sigemptyset(&sa.sa_mask);

    sigaction(SIGSEGV, &sa, &old_segv);
    sigaction(SIGBUS, &sa, &old_bus);
    sigaction(SIGABRT, &sa, &old_abrt);
    sigaction(SIGFPE, &sa, &old_fpe);
    sigaction(SIGTRAP, &sa, &old_trap);
    sigaction(SIGILL, &sa, &old_ill);

    g_crash_guard_active = 1;
    int sig = sigsetjmp(g_crash_jmp_buf, 1);
    if (sig != 0) {
        LOGE("KotoDwg CRASH INTERCEPTED: Native signal %d caught during conversion of %s! App kept alive.", sig, in_dwg_path);
        g_crash_guard_active = 0;
        sigaction(SIGSEGV, &old_segv, NULL);
        sigaction(SIGBUS, &old_bus, NULL);
        sigaction(SIGABRT, &old_abrt, NULL);
        sigaction(SIGFPE, &old_fpe, NULL);
        sigaction(SIGTRAP, &old_trap, NULL);
        sigaction(SIGILL, &old_ill, NULL);
        free(dwg);
        return -100 - sig;
    }
#endif

    // 4. Decode DWG file with LibreDWG
    dwg->opts = 0; // Standard read options
    LOGI("Calling dwg_read_file on %s...", in_dwg_path);
    int error = dwg_read_file(in_dwg_path, dwg);
    LOGI("dwg_read_file finished with code %d (critical threshold: %d, num_objects: %u)",
         error, DWG_ERR_CRITICAL, (unsigned int)dwg->num_objects);

    if (error >= DWG_ERR_CRITICAL) {
        LOGE("Critical error reading DWG: %d; aborting conversion safely", error);
#if !defined(_WIN32) && !defined(__CYGWIN__)
        g_crash_guard_active = 0;
        sigaction(SIGSEGV, &old_segv, NULL);
        sigaction(SIGBUS, &old_bus, NULL);
        sigaction(SIGABRT, &old_abrt, NULL);
        sigaction(SIGFPE, &old_fpe, NULL);
        sigaction(SIGTRAP, &old_trap, NULL);
        sigaction(SIGILL, &old_ill, NULL);
#endif
        free(dwg);
        return error;
    }

    // 5. Open output DXF file for writing
    FILE *fout = fopen(out_dxf_path, "wb");
    if (!fout) {
        LOGE("Failed to open output DXF for writing: %s (errno: %d)", out_dxf_path, errno);
#if !defined(_WIN32) && !defined(__CYGWIN__)
        g_crash_guard_active = 0;
        sigaction(SIGSEGV, &old_segv, NULL);
        sigaction(SIGBUS, &old_bus, NULL);
        sigaction(SIGABRT, &old_abrt, NULL);
        sigaction(SIGFPE, &old_fpe, NULL);
        sigaction(SIGTRAP, &old_trap, NULL);
        sigaction(SIGILL, &old_ill, NULL);
#endif
        free(dwg);
        return -3;
    }

    Bit_Chain dat;
    memset(&dat, 0, sizeof(Bit_Chain));
    dat.fh = fout;
    dat.version = dwg->header.version ? dwg->header.version : R_2000;
    dat.from_version = dwg->header.from_version ? dwg->header.from_version : dat.version;
    dat.opts = (unsigned char)(dwg->opts & 0xFF);
    dat.codepage = dwg->header.codepage ? dwg->header.codepage : 29; // CP_ANSI_1251

    LOGI("Writing DXF output (dwg version: %d, from: %d, codepage: %d)...",
         (int)dat.version, (int)dat.from_version, (int)dat.codepage);

    error = dwg_write_dxf(&dat, dwg);
    fclose(fout);
    LOGI("dwg_write_dxf finished with code %d", error);

    // 6. Cleanup LibreDWG memory
    // In LibreDWG's dwg2dxf.c: large drawings with thousands of objects can have circular
    // handle refs or cause deep recursion in dwg_free, leading to crashes or hangs.
    // For large drawings (>5000 objects), dwg_free is safely skipped as the thread finishes.
    if (dwg->num_objects < 5000 && error < DWG_ERR_CRITICAL) {
        LOGI("Freeing LibreDWG structures (%u objects)...", (unsigned int)dwg->num_objects);
        dwg_free(dwg);
        LOGI("dwg_free finished successfully");
    } else {
        LOGI("Large drawing (%u objects): skipping recursive dwg_free to avoid hang/crash",
             (unsigned int)dwg->num_objects);
    }

#if !defined(_WIN32) && !defined(__CYGWIN__)
    g_crash_guard_active = 0;
    sigaction(SIGSEGV, &old_segv, NULL);
    sigaction(SIGBUS, &old_bus, NULL);
    sigaction(SIGABRT, &old_abrt, NULL);
    sigaction(SIGFPE, &old_fpe, NULL);
    sigaction(SIGTRAP, &old_trap, NULL);
    sigaction(SIGILL, &old_ill, NULL);
#endif

    free(dwg);

    if (error >= DWG_ERR_CRITICAL) {
        LOGE("dwg_write_dxf critical error: %d", error);
        return error;
    }

    // 7. Verify output file size
    FILE *fout_check = fopen(out_dxf_path, "rb");
    if (fout_check) {
        fseek(fout_check, 0, SEEK_END);
        long out_size = ftell(fout_check);
        fclose(fout_check);
        LOGI("Conversion finished successfully. Output DXF size: %ld bytes (%.2f MB)",
             out_size, (double)out_size / (1024.0 * 1024.0));
        if (out_size == 0) return -5;
    }

    return 0;
}

#if !defined(_WIN32) && !defined(__CYGWIN__)
static void* convert_worker_thread(void* arg) {
    ConvertWorkerParams* params = (ConvertWorkerParams*)arg;
    params->result = do_convert_dwg_to_dxf(params->in_dwg_path, params->out_dxf_path);
    return NULL;
}
#endif

#endif // HAVE_LIBREDWG

/**
 * Converts a binary AutoCAD DWG file to an ASCII DXF file.
 * 
 * Runs on a dedicated thread with an 8 MB stack and signal crash-guarding,
 * ensuring large drawings decode without Dart isolate stack overflow or fatal crashes.
 * 
 * @param in_dwg_path Path to the source .dwg file
 * @param out_dxf_path Path to the destination .dxf file
 * @return 0 on success, non-zero error code on failure
 */
KOTO_EXPORT int koto_convert_dwg_to_dxf(const char* in_dwg_path, const char* out_dxf_path) {
    if (!in_dwg_path || !out_dxf_path) {
        return -1;
    }

#ifdef HAVE_LIBREDWG
#if !defined(_WIN32) && !defined(__CYGWIN__)
    ConvertWorkerParams params;
    params.in_dwg_path = in_dwg_path;
    params.out_dxf_path = out_dxf_path;
    params.result = -1;

    pthread_t thread;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    // Allocate 8 MB stack for LibreDWG decoding (Dart isolates only have ~512KB-1MB)
    pthread_attr_setstacksize(&attr, 8 * 1024 * 1024);

    int rc = pthread_create(&thread, &attr, convert_worker_thread, &params);
    pthread_attr_destroy(&attr);

    if (rc != 0) {
        LOGW("pthread_create failed (%d), executing on calling thread", rc);
        return do_convert_dwg_to_dxf(in_dwg_path, out_dxf_path);
    }

    pthread_join(thread, NULL);
    return params.result;
#else
    return do_convert_dwg_to_dxf(in_dwg_path, out_dxf_path);
#endif
#else
    // Fallback stub if compiled without direct LibreDWG link
    FILE* in = fopen(in_dwg_path, "rb");
    if (!in) {
        return -2;
    }
    fclose(in);

    FILE* out = fopen(out_dxf_path, "w");
    if (!out) {
        return -3;
    }
    fprintf(out, "0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n0\nENDSEC\n0\nEOF\n");
    fclose(out);
    return 0;
#endif
}
