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
    private static native int readDwgWithAcadrustDetailed(String input, int outputFd, byte[] diagnostic);

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
            byte[] diagnostic = new byte[4096];
            try (ParcelFileDescriptor descriptor = ParcelFileDescriptor.open(unicodeOutput,
                    ParcelFileDescriptor.MODE_CREATE | ParcelFileDescriptor.MODE_TRUNCATE | ParcelFileDescriptor.MODE_WRITE_ONLY)) {
                result = readDwgWithAcadrustDetailed(unicodeInput.getPath(), descriptor.getFd(), diagnostic);
            }
            if (result != 0) throw new AssertionError(input.getName() + ": JNI result " + result
                    + ": " + new String(diagnostic, StandardCharsets.UTF_8).trim());
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
            byte[] diagnostic = new byte[4096];
            if (readDwgWithAcadrustDetailed(invalid.getPath(), descriptor.getFd(), diagnostic) == 0) {
                throw new AssertionError("Invalid DWG accepted");
            }
            String reason = new String(diagnostic, StandardCharsets.UTF_8).trim();
            if (!reason.contains("Unsupported CAD version")) {
                throw new AssertionError("Native failure reason was lost: " + reason);
            }
            System.out.println("PASS corrupt input diagnostic: " + reason);
        }
        System.out.println("JNI checks passed: " + passed + " drawings, corrupt input, Unicode paths, overwrite protection");
    }
}
