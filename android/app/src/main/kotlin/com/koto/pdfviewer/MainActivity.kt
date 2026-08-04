package com.koto.pdfviewer

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.koto.pdfviewer/intent"
    private var initialPdfPath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent, isInitial = true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, isInitial = false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialPdfPath") {
                result.success(initialPdfPath)
                initialPdfPath = null
            } else {
                result.notImplemented()
            }
        }
    }

    private fun handleIntent(intent: Intent?, isInitial: Boolean) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        var uri: Uri? = null
        if (Intent.ACTION_VIEW == action) {
            uri = intent.data
        } else if (Intent.ACTION_SEND == action && (type?.startsWith("application/pdf") == true || type == "*/*")) {
            uri = intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        } else if (intent.data != null) {
            uri = intent.data
        }

        if (uri != null) {
            val localPath = resolveUriToFilePath(uri)
            if (localPath != null) {
                if (isInitial || methodChannel == null) {
                    initialPdfPath = localPath
                } else {
                    methodChannel?.invokeMethod("onPdfOpened", localPath)
                }
            }
        }
    }

    private fun resolveUriToFilePath(uri: Uri): String? {
        return try {
            val scheme = uri.scheme?.lowercase()
            if (scheme == "file") {
                uri.path
            } else if (scheme == "content") {
                val fileName = getFileName(uri) ?: "opened_document.pdf"
                val sanitizedFileName = if (fileName.endsWith(".pdf", ignoreCase = true)) fileName else "$fileName.pdf"
                val tempFile = File(cacheDir, sanitizedFileName)
                val inputStream = contentResolver.openInputStream(uri)
                    ?: throw java.io.FileNotFoundException("Could not open input stream for URI: $uri")
                inputStream.use { input ->
                    FileOutputStream(tempFile).use { output ->
                        input.copyTo(output)
                    }
                }
                tempFile.absolutePath
            } else {
                uri.path
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to resolve URI to file path: $uri", e)
            null
        }
    }

    private fun getFileName(uri: Uri): String? {
        var result: String? = null
        if (uri.scheme == "content") {
            try {
                val cursor = contentResolver.query(uri, null, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val index = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                        if (index != -1) {
                            result = it.getString(index)
                        }
                    }
                }
            } catch (e: Exception) {
                android.util.Log.w("MainActivity", "Could not query display name for URI: $uri", e)
            }
        }
        if (result == null) {
            result = uri.path
            val cut = result?.lastIndexOf('/')
            if (cut != null && cut != -1) {
                result = result.substring(cut + 1)
            }
        }
        return result
    }
}
