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

        var uri: Uri? = null

        if (Intent.ACTION_VIEW == action) {
            uri = intent.data ?: intent.clipData?.getItemAt(0)?.uri
        } else if (Intent.ACTION_SEND == action) {
            uri = (intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri)
                ?: intent.clipData?.getItemAt(0)?.uri
                ?: intent.data
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            val list = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            uri = list?.firstOrNull() ?: intent.clipData?.getItemAt(0)?.uri
        } else if (intent.data != null) {
            uri = intent.data
        } else if (intent.clipData != null && intent.clipData!!.itemCount > 0) {
            uri = intent.clipData!!.getItemAt(0).uri
        }

        if (uri != null) {
            val localPath = resolveUriToFilePath(uri)
            if (localPath != null) {
                initialPdfPath = localPath
                methodChannel?.invokeMethod("onPdfOpened", localPath)
            }
        }
    }

    private fun resolveUriToFilePath(uri: Uri): String? {
        return try {
            val scheme = uri.scheme?.lowercase()
            if (scheme == "file") {
                uri.path
            } else if (scheme == "content") {
                val fileName = getFileName(uri) ?: "shared_document"
                val sanitizedFileName = if (fileName.contains(".")) {
                    fileName
                } else {
                    val mime = contentResolver.getType(uri)?.lowercase() ?: ""
                    when {
                        mime.contains("pdf") -> "$fileName.pdf"
                        mime.contains("dxf") || mime.contains("autocad") -> "$fileName.dxf"
                        mime.contains("dwg") -> "$fileName.dwg"
                        mime.contains("svg") -> "$fileName.svg"
                        mime.contains("stl") -> "$fileName.stl"
                        mime.contains("obj") -> "$fileName.obj"
                        mime.contains("step") || mime.contains("stp") -> "$fileName.step"
                        mime.contains("iges") || mime.contains("igs") -> "$fileName.iges"
                        mime.contains("spreadsheet") || mime.contains("excel") || mime.contains("sheet") -> "$fileName.xlsx"
                        mime.contains("word") || mime.contains("document") -> "$fileName.docx"
                        mime.contains("text") || mime.contains("plain") -> "$fileName.txt"
                        mime.contains("markdown") -> "$fileName.md"
                        else -> "$fileName.pdf"
                    }
                }
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

            // Filter only email apps by package name
            val emailApps = listOf(
                "com.google.android.gm",
                "com.google.android.gm.lite",
                "com.microsoft.office.outlook",
                "com.microsoft.outlooklite",
                "com.samsung.android.email.provider",
                "com.yahoo.mobile.client.android.mail",
                "com.aol.mobile.aolapp",
                "com.fsck.k9",
                "com.google.android.apps.inbox",
                "me.bluemail.mail",
                "ch.protonmail.android",
                "com.tutanota",
                "com.myriad.mobile.email.android",
                "com.sonyericsson.email",
                "com.lge.email",
                "com.htc.android.mail",
                "com.asus.email",
                "com.motorola.email"
            )

            val targetedIntents = mutableListOf<Intent>()
            val resInfo = packageManager.queryIntentActivities(sendIntent, 0)
            
            for (info in resInfo) {
                val packageName = info.activityInfo.packageName
                val activityName = info.activityInfo.name.lowercase()
                if (emailApps.any { packageName.contains(it, ignoreCase = true) } || 
                    activityName.contains("email") || 
                    activityName.contains("mail")) {
                    val targetIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_SUBJECT, subject ?: "PDF Document")
                        setPackage(packageName)
                        setClassName(packageName, info.activityInfo.name)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    targetedIntents.add(targetIntent)
                }
            }

            // Fallback: also try ACTION_SENDTO with mailto: to catch more email apps
            val fallbackIntent = Intent(Intent.ACTION_SEND).apply {
                type = "message/rfc822"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, subject ?: "PDF Document")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            val emailSelector = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("mailto:")
            }
            fallbackIntent.selector = emailSelector

            val fallbackResInfo = packageManager.queryIntentActivities(fallbackIntent, 0)
            for (info in fallbackResInfo) {
                val packageName = info.activityInfo.packageName
                if (targetedIntents.none { it.component?.packageName == packageName }) {
                    val targetIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "message/rfc822"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_SUBJECT, subject ?: "PDF Document")
                        setPackage(packageName)
                        setClassName(packageName, info.activityInfo.name)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    targetedIntents.add(targetIntent)
                }
            }

            val chooserIntent: Intent
            if (targetedIntents.isNotEmpty()) {
                chooserIntent = Intent.createChooser(targetedIntents.removeAt(0), "Choose email app")
                if (targetedIntents.isNotEmpty()) {
                    chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, targetedIntents.toTypedArray())
                }
            } else {
                chooserIntent = Intent.createChooser(sendIntent, "Send via Email")
            }
            
            chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooserIntent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // Share to MESSAGING APPS ONLY (Viber, WhatsApp, Messenger, Telegram, etc.)
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

            // Filter only messaging apps - expanded list
            val messagingApps = listOf(
                "com.viber.voip",
                "com.viber.voip.lite",
                "com.whatsapp",
                "com.whatsapp.w4b",
                "com.whatsapp.lite",
                "com.facebook.orca",
                "com.facebook.mlite",
                "com.facebook.lite",
                "org.telegram.messenger",
                "org.telegram.messenger.web",
                "org.telegram.plus",
                "tw.com.funtv.telegram",
                "com.snapchat.android",
                "com.skype.raider",
                "com.skype.m2",
                "com.microsoft.teams",
                "com.microsoft.teams.lite",
                "com.discord",
                "com.discord.lite",
                "com.slack",
                "com.Slack",
                "com.wechat",
                "com.tencent.mm",
                "com.tencent.wework",
                "jp.naver.line.android",
                "jp.naver.line.lite.android",
                "com.kakao.talk",
                "com.vkontakte.android",
                "ru.mail.mailapp",
                "ru.ok.android",
                "com.zangi",
                "com.imo.android.imois",
                "com.imo.android.imoim",
                "com.bbm",
                "com.wickrinc.me",
                "th.co.truecorp.truefriend",
                "com.bsb.hike",
                "com.sendbird.android.shadow",
                "com.wire",
                "com.surespot",
                "com.messenger.sms"
            )

            val targetedIntents = mutableListOf<Intent>()
            val resInfo = packageManager.queryIntentActivities(sendIntent, 0)
            
            for (info in resInfo) {
                val packageName = info.activityInfo.packageName
                val activityName = info.activityInfo.name.lowercase()
                if (messagingApps.any { packageName.contains(it, ignoreCase = true) } ||
                    activityName.contains("whatsapp") ||
                    activityName.contains("viber") ||
                    activityName.contains("telegram") ||
                    activityName.contains("messenger") ||
                    activityName.contains("sms") ||
                    activityName.contains("mms")) {
                    val targetIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_TEXT, text)
                        setPackage(packageName)
                        setClassName(packageName, info.activityInfo.name)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    targetedIntents.add(targetIntent)
                }
            }

            val chooserIntent: Intent
            if (targetedIntents.isNotEmpty()) {
                chooserIntent = Intent.createChooser(targetedIntents.removeAt(0), "Choose messaging app")
                if (targetedIntents.isNotEmpty()) {
                    chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, targetedIntents.toTypedArray())
                }
            } else {
                chooserIntent = Intent.createChooser(sendIntent, "Share via message")
            }

            chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooserIntent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // Share to CLOUD STORAGE ONLY (Google Drive, Dropbox, OneDrive, etc.)
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

            // Filter only cloud storage apps - expanded list
            val cloudApps = listOf(
                "com.google.android.apps.docs",
                "com.google.android.apps.docs.editors.docs",
                "com.google.android.apps.docs.editors.sheets",
                "com.google.android.apps.docs.editors.slides",
                "com.dropbox.android",
                "com.dropbox.android.lite",
                "com.microsoft.skydrive",
                "com.microsoft.office.onenote",
                "com.microsoft.office.word",
                "com.microsoft.office.excel",
                "com.microsoft.office.powerpoint",
                "com.microsoft.office.officehub",
                "com.microsoft.office.officelens",
                "com.box.android",
                "com.box.androidlite",
                "com.amazon.drive",
                "com.amazon.clouddrive",
                "com.evernote",
                "com.evernote.skitch",
                "com.ideashower.readitlater.pro",
                "com.getpocket",
                "com.microsoft.todos",
                "com.todoist",
                "com.notion.id",
                "pl.solidexplorer2",
                "com.alphainventor.filemanager",
                "com.estrongs.android.pop",
                "com.mi.android.globalFileexplorer",
                "com.samsung.android.myfiles",
                "com.sec.android.app.myfiles",
                "com.lenovo.FileBrowser",
                "com.asus.filemanager",
                "com.lge.filemanager",
                "com.huawei.hidisk",
                "com.huawei.files",
                "com.xiaomi.midrop",
                "com.opera.browser",
                "com.android.chrome",
                "org.mozilla.firefox",
                "com.microsoft.emmx"
            )

            val targetedIntents = mutableListOf<Intent>()
            val resInfo = packageManager.queryIntentActivities(sendIntent, 0)
            
            for (info in resInfo) {
                val packageName = info.activityInfo.packageName
                val activityName = info.activityInfo.name.lowercase()
                if (cloudApps.any { packageName.contains(it, ignoreCase = true) } ||
                    activityName.contains("drive") ||
                    activityName.contains("dropbox") ||
                    activityName.contains("onedrive") ||
                    activityName.contains("skydrive") ||
                    activityName.contains("cloud") ||
                    activityName.contains("storage") ||
                    activityName.contains("upload") ||
                    activityName.contains("backup") ||
                    activityName.contains("save")) {
                    val targetIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        setPackage(packageName)
                        setClassName(packageName, info.activityInfo.name)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    targetedIntents.add(targetIntent)
                }
            }

            val chooserIntent: Intent
            if (targetedIntents.isNotEmpty()) {
                chooserIntent = Intent.createChooser(targetedIntents.removeAt(0), "Choose cloud storage")
                if (targetedIntents.isNotEmpty()) {
                    chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, targetedIntents.toTypedArray())
                }
            } else {
                chooserIntent = Intent.createChooser(sendIntent, "Upload to cloud")
            }

            chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
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
