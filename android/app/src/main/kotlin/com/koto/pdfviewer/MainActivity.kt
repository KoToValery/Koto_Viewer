package com.koto.pdfviewer

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.koto.pdfviewer/intent"
    private val SHARE_CHANNEL = "com.koto.pdf_viewer/share"
    private var initialPdfPath: String? = null
    private var methodChannel: MethodChannel? = null
    private var shareMethodChannel: MethodChannel? = null

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
        
        // Original intent channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialPdfPath") {
                result.success(initialPdfPath)
                initialPdfPath = null
            } else {
                result.notImplemented()
            }
        }
        
        // Share channel
        shareMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        shareMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "shareViaEmail" -> {
                    val filePath = call.argument<String>("filePath")
                    val subject = call.argument<String>("subject")
                    if (filePath != null) {
                        val success = shareViaEmail(filePath, subject)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                    }
                }
                "shareViaMessaging" -> {
                    val filePath = call.argument<String>("filePath")
                    val text = call.argument<String>("text")
                    if (filePath != null) {
                        val success = shareViaMessaging(filePath, text)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                    }
                }
                "shareViaCloud" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val success = shareViaCloud(filePath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                    }
                }
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        try {
                            val installed = isAppInstalled(packageName)
                            result.success(installed)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
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
    
    // Share to EMAIL APPS ONLY
    private fun shareViaEmail(filePath: String, subject: String?): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, subject ?: "PDF Document")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            // Email selector - shows ONLY email apps
            val emailIntent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("mailto:")
            }
            sendIntent.selector = emailIntent

            if (sendIntent.resolveActivity(packageManager) != null) {
                startActivity(sendIntent)
                true
            } else {
                startActivity(Intent.createChooser(sendIntent, "Изпрати по Email"))
                true
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // Share to MESSAGING APPS ONLY (Viber, WhatsApp, Messenger, Telegram)
    private fun shareViaMessaging(filePath: String, text: String?): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, text ?: "")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            // Filter only messaging apps
            val messagingApps = listOf(
                "com.viber.voip",
                "com.whatsapp",
                "com.facebook.orca",
                "org.telegram.messenger"
            )

            val targetedIntents = mutableListOf<Intent>()
            val resInfo = packageManager.queryIntentActivities(sendIntent, 0)
            
            for (info in resInfo) {
                val packageName = info.activityInfo.packageName
                if (messagingApps.any { packageName.contains(it) }) {
                    val targetIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_TEXT, text)
                        setPackage(packageName)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    targetedIntents.add(targetIntent)
                }
            }

            val chooserIntent = Intent.createChooser(sendIntent, "Изпрати по съобщение")
            if (targetedIntents.isNotEmpty()) {
                chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, targetedIntents.toTypedArray())
            }
            
            startActivity(chooserIntent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // Share to CLOUD STORAGE ONLY (Google Drive, Dropbox, OneDrive)
    private fun shareViaCloud(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            // Filter only cloud storage apps
            val cloudApps = listOf(
                "com.google.android.apps.docs",
                "com.dropbox.android",
                "com.microsoft.skydrive",
                "com.box.android"
            )

            val targetedIntents = mutableListOf<Intent>()
            val resInfo = packageManager.queryIntentActivities(sendIntent, 0)
            
            for (info in resInfo) {
                val packageName = info.activityInfo.packageName
                if (cloudApps.any { packageName.contains(it) }) {
                    val targetIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        setPackage(packageName)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    targetedIntents.add(targetIntent)
                }
            }

            val chooserIntent = Intent.createChooser(sendIntent, "Качи в облак")
            if (targetedIntents.isNotEmpty()) {
                chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, targetedIntents.toTypedArray())
            }
            
            startActivity(chooserIntent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // Check if app is installed
    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            val packageManager = applicationContext.packageManager
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }
}
