package com.koto.kotoviewer

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.*
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** Object stream from :dwg_converter through a pipe, avoiding Binder's 1 MB limit. */
class AndroidDwgReaderClient(private val context: Context) {
    fun read(inputPath: String, result: MethodChannel.Result) {
        val handler = Handler(Looper.getMainLooper())
        val requestId = SystemClock.elapsedRealtimeNanos()
        val pipe = ParcelFileDescriptor.createPipe()
        val executor = Executors.newSingleThreadExecutor()
        var worker: Messenger? = null
        var finished = false
        var bound = false
        var bytes: ByteArray? = null
        var status: Int? = null
        lateinit var connection: ServiceConnection
        lateinit var timeout: Runnable

        fun finish(code: String? = null) {
            if (finished) return
            if (code == null && (bytes == null || status == null)) return
            finished = true
            handler.removeCallbacks(timeout)
            if (code != null) {
                try {
                    worker?.send(Message.obtain(null, DwgConverterService.MSG_CANCEL).apply {
                        data = Bundle().apply { putLong(DwgConverterService.KEY_REQUEST_ID, requestId) }
                    })
                } catch (_: Exception) {}
            }
            try { pipe[0].close() } catch (_: Exception) {}
            try { pipe[1].close() } catch (_: Exception) {}
            if (bound) {
                bound = false
                try { context.unbindService(connection) } catch (_: Exception) {}
            }
            executor.shutdownNow()
            if (code != null) result.error(code, "Native DWG reader failed", null)
            else if (status != 0 || bytes!!.isEmpty()) result.error("DWG_READ_FAILED", "Native DWG reader rejected the drawing", null)
            else result.success(bytes)
        }
        timeout = Runnable { finish("CONVERSION_TIMEOUT") }
        val reply = Messenger(object : Handler(Looper.getMainLooper()) {
            override fun handleMessage(message: Message) {
                if (message.what == DwgConverterService.MSG_RESULT) {
                    status = message.data.getInt(DwgConverterService.KEY_RESULT_CODE, -1)
                    finish()
                }
            }
        })
        connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                if (finished) return
                try {
                    worker = Messenger(binder)
                    worker!!.send(Message.obtain(null, DwgConverterService.MSG_READ).apply {
                        data = Bundle().apply {
                            putString(DwgConverterService.KEY_INPUT_PATH, inputPath)
                            putLong(DwgConverterService.KEY_REQUEST_ID, requestId)
                            putParcelable(DwgConverterService.KEY_OBJECT_PIPE, pipe[1])
                        }
                        replyTo = reply
                    })
                    pipe[1].close()
                } catch (_: Exception) { finish("CONVERT_SEND_FAILED") }
            }
            override fun onServiceDisconnected(name: ComponentName?) { finish("OOM_KILLED") }
            override fun onBindingDied(name: ComponentName?) { finish("OOM_KILLED") }
            override fun onNullBinding(name: ComponentName?) { finish("BIND_FAILED") }
        }
        try {
            bound = context.bindService(Intent(context, DwgConverterService::class.java), connection, Context.BIND_AUTO_CREATE)
            if (!bound) { finish("BIND_FAILED"); return }
            handler.postDelayed(timeout, 120_000L)
            executor.execute {
                try {
                    val payload = ByteArrayOutputStream()
                    ParcelFileDescriptor.AutoCloseInputStream(pipe[0]).use { input ->
                        val chunk = ByteArray(65536)
                        while (true) {
                            val count = input.read(chunk)
                            if (count < 0) break
                            if (payload.size().toLong() + count > 256L * 1024 * 1024) {
                                handler.post { finish("OOM_KILLED") }
                                return@execute
                            }
                            payload.write(chunk, 0, count)
                        }
                    }
                    val value = payload.toByteArray()
                    handler.post { bytes = value; finish() }
                } catch (_: Exception) { handler.post { finish("DWG_STREAM_FAILED") } }
                catch (_: OutOfMemoryError) { handler.post { finish("OOM_KILLED") } }
            }
        } catch (_: Exception) { finish("BIND_FAILED") }
    }
}
