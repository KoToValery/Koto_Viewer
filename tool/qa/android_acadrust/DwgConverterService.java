package com.koto.kotoviewer;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import android.os.ParcelFileDescriptor;

/** Standalone ART/JNI smoke test; this is not included in the application. */
public final class DwgConverterService {
    private static native int convertDwgWithAcadrust(String input, String output);
    private static native int readDwgWithAcadrust(String input, int outputFd);

    public static void main(String[] args) throws Exception {
        System.load(args[0]);
        File folder = new File(args[1]);
        File outputs = new File(folder, "output");
        outputs.mkdirs();
        int passed = 0;
        for (File input : folder.listFiles()) {
            if (!input.getName().endsWith(".dwg")) continue;
            // Construct Java strings containing a surrogate pair. JNI Modified
            // UTF-8 would corrupt this filename if GetStringUTFChars were used.
            File unicodeInput = new File(outputs, "Чертеж 🏠.dwg");
            File unicodeOutput = new File(outputs, input.getName() + " 🏠.objects.json");
            Files.copy(input.toPath(), unicodeInput.toPath(), StandardCopyOption.REPLACE_EXISTING);
            int result;
            try (ParcelFileDescriptor descriptor = ParcelFileDescriptor.open(unicodeOutput,
                    ParcelFileDescriptor.MODE_CREATE | ParcelFileDescriptor.MODE_TRUNCATE | ParcelFileDescriptor.MODE_WRITE_ONLY)) {
                result = readDwgWithAcadrust(unicodeInput.getPath(), descriptor.getFd());
            }
            if (result != 0) throw new AssertionError(input.getName() + ": JNI result " + result);
            String text = new String(Files.readAllBytes(unicodeOutput.toPath()), StandardCharsets.UTF_8);
            if (!text.contains("\"source\":\"DWG\"") || !text.contains("\"protocol\":1") || !text.trim().endsWith("}")) {
                throw new AssertionError("Incomplete native objects: " + input.getName());
            }
            if (convertDwgWithAcadrust(unicodeInput.getPath(), unicodeInput.getPath()) == 0) {
                throw new AssertionError("Input overwrite was allowed");
            }
            System.out.println("PASS " + input.getName() + " bytes=" + unicodeOutput.length());
            passed++;
        }
        if (passed == 0) throw new AssertionError("No DWG fixtures found");
        File invalid = new File(outputs, "bad.dwg");
        Files.write(invalid.toPath(), "not a DWG".getBytes(StandardCharsets.UTF_8));
        try (ParcelFileDescriptor descriptor = ParcelFileDescriptor.open(new File(outputs, "bad.objects.json"),
                ParcelFileDescriptor.MODE_CREATE | ParcelFileDescriptor.MODE_WRITE_ONLY)) {
            if (readDwgWithAcadrust(invalid.getPath(), descriptor.getFd()) == 0) {
                throw new AssertionError("Invalid DWG accepted");
            }
        }
        System.out.println("JNI checks passed: " + passed + " drawings, corrupt input, Unicode paths, overwrite protection");
    }
}
