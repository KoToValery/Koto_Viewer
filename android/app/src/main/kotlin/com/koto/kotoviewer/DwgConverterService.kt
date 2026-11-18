package com.koto.kotoviewer

import android.app.Service
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.util.Log
import java.util.concurrent.Executors
import java.util.Collections

/**
 * Dedicated background Android Service running in an isolated process (:dwg_converter).
 * 
 * Both acadrust and LibreDWG execute here. Native faults and memory pressure in
 * the converter process are reported to Flutter through the service connection.
 */
class DwgConverterService : Service() {

    companion object {
        private const val TAG = "DwgConverterService"
        const val MSG_CONVERT = 1
        const val MSG_RESULT = 2
        const val MSG_CANCEL = 3
        const val MSG_READ = 4
        const val KEY_OBJECT_PIPE = "object_pipe"
        const val KEY_INPUT_PATH = "input_path"
        const val KEY_OUTPUT_PATH = "output_path"
        const val KEY_RESULT_CODE = "result_code"
        const val KEY_BACKEND = "backend"
        const val KEY_REQUEST_ID = "request_id"

        // Lazy loading is essential: MainActivity also references this class's
        // protocol constants. Native libraries belong only in the worker.
        private val acadrustLoaded by lazy { loadLibrary("koto_acadrust") }
        private val libreDwgLoaded by lazy {
            loadLibrary("redwg") && loadLibrary("koto_dwg")
        }

        private fun loadLibrary(name: String): Boolean {
            try {
                System.loadLibrary(name)
                return true
            } catch (error: LinkageError) {
                Log.w(TAG, "Native backend unavailable: $name", error)
            } catch (error: SecurityException) {
                Log.w(TAG, "Native backend load denied: $name", error)
            }
            return false
        }

        @JvmStatic
        external fun convertDwgToDxf(inDwgPath: String, outDxfPath: String): Int

        @JvmStatic
        external fun convertDwgWithAcadrust(inDwgPath: String, outDxfPath: String): Int

        @JvmStatic
        external fun readDwgWithAcadrust(inDwgPath: String, outputFd: Int): Int

        private fun convert(backend: String, input: String, output: String): Int = when (backend) {
            "acadrust" -> if (acadrustLoaded) convertDwgWithAcadrust(input, output) else -97
            "libredwg" -> if (libreDwgLoaded) convertDwgToDxf(input, output) else -97
            else -> -98
        }
    }

    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var messenger: Messenger
    @Volatile private var activeRequestId: Long? = null
    private val cancelledRequests = Collections.synchronizedSet(mutableSetOf<Long>())

    private class IncomingHandler(private val service: DwgConverterService) : Handler(Looper.getMainLooper()) {
        override fun handleMessage(msg: Message) {
            when (msg.what) {
                MSG_READ -> {
                    val input = msg.data.getString(KEY_INPUT_PATH) ?: return
                    @Suppress("DEPRECATION")
                    val pipe = msg.data.getParcelable<android.os.ParcelFileDescriptor>(KEY_OBJECT_PIPE) ?: return
                    val reply = msg.replyTo ?: run { pipe.close(); return }
                    val requestId = msg.data.getLong(KEY_REQUEST_ID)
                    service.executor.execute {
                        service.activeRequestId = requestId
                        var result = -97
                        try {
                            if (!service.cancelledRequests.remove(requestId) && acadrustLoaded) {
                                result = readDwgWithAcadrust(input, pipe.fd)
                            }
                        } catch (error: Throwable) {
                            Log.e(TAG, "Direct DWG read failed", error)
                            result = -99
                        } finally {
                            pipe.close()
                            service.activeRequestId = null
                        }
                        try {
                            reply.send(Message.obtain(null, MSG_RESULT).apply {
                                data = Bundle().apply { putInt(KEY_RESULT_CODE, result) }
                            })
                        } catch (_: Exception) {}
                    }
                }
                MSG_CONVERT -> {
                    val data = msg.data
                    val inPath = data.getString(KEY_INPUT_PATH)
                    val outPath = data.getString(KEY_OUTPUT_PATH)
                    val replyTo = msg.replyTo
                    val backend = data.getString(KEY_BACKEND) ?: "libredwg"
                    val requestId = data.getLong(KEY_REQUEST_ID)

                    if (inPath == null || outPath == null || replyTo == null) {
                        Log.e(TAG, "Invalid convert request: inPath=$inPath, outPath=$outPath, replyTo=$replyTo")
                        return
                    }

                    service.executor.execute {
                        service.activeRequestId = requestId
                        if (service.cancelledRequests.remove(requestId)) {
                            service.activeRequestId = null
                            return@execute
                        }
                        Log.i(TAG, "Starting $backend conversion in worker process")
                        var resultCode = -1
                        try {
                            resultCode = convert(backend, inPath, outPath)
                            Log.i(TAG, "Conversion completed in isolated process with code: $resultCode")
                        } catch (t: Throwable) {
                            Log.e(TAG, "Exception during conversion in isolated process: ${t.message}", t)
                            resultCode = -99
                        } finally {
                            service.activeRequestId = null
                        }

                        val reply = Message.obtain(null, MSG_RESULT)
                        val replyData = Bundle()
                        replyData.putInt(KEY_RESULT_CODE, resultCode)
                        reply.data = replyData

                        try {
                            replyTo.send(reply)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to send result back to client: ${e.message}")
                        }
                    }
                }
                MSG_CANCEL -> {
                    val requestId = msg.data.getLong(KEY_REQUEST_ID)
                    service.cancelledRequests.add(requestId)
                    if (service.activeRequestId == requestId) {
                        // A timed-out JNI call cannot be interrupted safely.
                        // Terminate only this worker; the UI already has its timeout.
                        android.os.Process.killProcess(android.os.Process.myPid())
                    }
                }
                else -> super.handleMessage(msg)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        messenger = Messenger(IncomingHandler(this))
        Log.i(TAG, "DwgConverterService created in process PID: ${android.os.Process.myPid()}")
    }

    override fun onBind(intent: Intent?): IBinder? {
        Log.i(TAG, "DwgConverterService onBind called")
        return messenger.binder
    }

    override fun onDestroy() {
        super.onDestroy()
        executor.shutdown()
        Log.i(TAG, "DwgConverterService destroyed")
    }
}
