package com.app.prepzo

import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var linksChannel: MethodChannel? = null
    // App Link the activity was launched with, handed to Dart once.
    private var initialLink: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        initialLink = linkFrom(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        linkFrom(intent)?.let { linksChannel?.invokeMethod("onLink", it) }
    }

    private fun linkFrom(intent: Intent?): String? =
        if (intent?.action == Intent.ACTION_VIEW) intent.dataString else null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerFilesChannel(flutterEngine)
        registerLinksChannel(flutterEngine)
    }

    private fun registerLinksChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prepzo/links")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(initialLink)
                    initialLink = null
                }
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val subject = call.argument<String>("subject") ?: ""
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                        if (subject.isNotEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
                    }
                    try {
                        startActivity(Intent.createChooser(send, "Share via"))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("share_failed", e.message ?: "No app available to share", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        linksChannel = channel
    }

    private fun registerFilesChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prepzo/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "saveToDownloads" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "download.pdf"
                        val mime = call.argument<String>("mimeType") ?: "application/pdf"
                        if (bytes == null) {
                            result.error("bad_args", "No file data", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                saveToDownloads(bytes, fileName, mime) { uri ->
                                    runOnUiThread {
                                        if (uri == null) result.error("save_failed", "Could not save the file", null)
                                        else result.success(mapOf("uri" to uri.toString(), "displayPath" to "Downloads/$fileName"))
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("save_failed", e.message ?: "Could not save the file", null) }
                            }
                        }.start()
                    }
                    "openFile" -> {
                        val uri = Uri.parse(call.argument<String>("uri") ?: "")
                        val mime = call.argument<String>("mimeType") ?: "application/pdf"
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, mime)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "shareFile" -> {
                        val uri = Uri.parse(call.argument<String>("uri") ?: "")
                        val mime = call.argument<String>("mimeType") ?: "application/pdf"
                        val subject = call.argument<String>("subject") ?: ""
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = mime
                            putExtra(Intent.EXTRA_STREAM, uri)
                            if (subject.isNotEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        try {
                            startActivity(Intent.createChooser(send, "Share receipt"))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("share_failed", e.message ?: "No app available to share", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Android 10+: MediaStore Downloads (no permission). Android 8-9: public
    // Downloads folder (WRITE_EXTERNAL_STORAGE, asked for in Dart) + media scan
    // so the file gets a shareable content:// uri.
    private fun saveToDownloads(bytes: ByteArray, fileName: String, mime: String, done: (Uri?) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            // Replace an earlier copy of the same receipt instead of piling up "(1)" files.
            resolver.query(
                collection,
                arrayOf(MediaStore.Downloads._ID),
                "${MediaStore.Downloads.DISPLAY_NAME} = ?",
                arrayOf(fileName),
                null
            )?.use { c ->
                while (c.moveToNext()) {
                    try {
                        resolver.delete(Uri.withAppendedPath(collection, c.getLong(0).toString()), null, null)
                    } catch (_: Exception) {
                    }
                }
            }
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(collection, values) ?: return done(null)
            resolver.openOutputStream(uri)?.use { it.write(bytes) } ?: return done(null)
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            done(uri)
        } else {
            @Suppress("DEPRECATION")
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, fileName)
            file.writeBytes(bytes)
            val main = Handler(Looper.getMainLooper())
            MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), arrayOf(mime)) { _, uri ->
                main.post { done(uri) }
            }
        }
    }
}
