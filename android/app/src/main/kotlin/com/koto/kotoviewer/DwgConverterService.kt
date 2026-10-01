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

/**
 * Dedicated background Android Service running in an isolated process (:dwg_converter).
 * 
 * By executing LibreDWG conversion in this separate process:
 * 1. The main application (Flutter UI engine) is 100% protected against Out-Of-Memory (OOM)
 *    kills or native crashes caused by complex or corrupt DWG files.
 * 2. If the OS terminates this process due to memory limits, the main app stays alive
 *    and gracefully notifies the user with a localized dialog.
 */
class DwgConverterService : Service() {

    companion object {
        private const val TAG = "DwgConverterService"
        const val MSG_CONVERT = 1
        const val MSG_RESULT = 2
        const val KEY_INPUT_PATH = "input_path"
        const val KEY_OUTPUT_PATH = "output_path"
        const val KEY_RESULT_CODE = "result_code"

        init {
            try {
                System.loadLibrary("redwg")
                Log.i(TAG, "libredwg.so loaded successfully in :dwg_converter process")
            } catch (t: Throwable) {
                Log.w(TAG, "Failed preloading libredwg.so: ${t.message}")
            }
            try {
                System.loadLibrary("koto_dwg")
                Log.i(TAG, "libkoto_dwg.so loaded successfully in :dwg_converter process")
            } catch (t: Throwable) {
                Log.e(TAG, "Failed loading libkoto_dwg.so: ${t.message}", t)
            }
        }

        @JvmStatic
        external fun convertDwgToDxf(inDwgPath: String, outDxfPath: String): Int
    }

    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var messenger: Messenger

    private class IncomingHandler(private val service: DwgConverterService) : Handler(Looper.getMainLooper()) {
        override fun handleMessage(msg: Message) {
            when (msg.what) {
                MSG_CONVERT -> {
                    val data = msg.data
                    val inPath = data.getString(KEY_INPUT_PATH)
                    val outPath = data.getString(KEY_OUTPUT_PATH)
                    val replyTo = msg.replyTo

                    if (inPath == null || outPath == null || replyTo == null) {
                        Log.e(TAG, "Invalid convert request: inPath=$inPath, outPath=$outPath, replyTo=$replyTo")
                        return
                    }

                    service.executor.execute {
                        Log.i(TAG, "Starting conversion in isolated process: $inPath -> $outPath")
                        var resultCode = -1
                        try {
                            resultCode = convertDwgToDxf(inPath, outPath)
                            Log.i(TAG, "Conversion completed in isolated process with code: $resultCode")
                        } catch (t: Throwable) {
                            Log.e(TAG, "Exception during conversion in isolated process: ${t.message}", t)
                            resultCode = -99
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
