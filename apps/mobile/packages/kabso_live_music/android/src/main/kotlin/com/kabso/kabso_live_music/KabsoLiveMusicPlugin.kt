package com.kabso.kabso_live_music

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

/**
 * D201: the Dart side of [MusicMixer] (`com.kabso/live_music`).
 *
 * - `pick`: the system document picker for audio files (`ACTION_OPEN_DOCUMENT`,
 *   any audio type, several at once). No storage permission: the picker grants the
 *   chosen files only; each is copied into the app's cache (≤ 50 MB each) so the
 *   decoder can read it; answers `[{path, name}]`.
 * - `load {path}` → duration ms; `play`, `pause`, `stop`, `setVolume {volume}`,
 *   `setDucking {on}`.
 * - Back to Dart: `position {positionMs, durationMs}`, `completed`, `error`.
 *
 * The mixer joins flutter_webrtc's capture post-processing on the first `load`
 * (its audio module exists once the live's microphone track was created) and
 * leaves it on `stop` and when the engine detaches.
 */
class KabsoLiveMusicPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var cacheDir: File? = null
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var attached = false

    private val mixer =
        MusicMixer(
            object : MusicMixer.Events {
                override fun position(positionMs: Long, durationMs: Long) {
                    main.post {
                        channel?.invokeMethod(
                            "position",
                            mapOf("positionMs" to positionMs, "durationMs" to durationMs),
                        )
                    }
                }

                override fun completed() {
                    main.post { channel?.invokeMethod("completed", null) }
                }

                override fun failed() {
                    main.post { channel?.invokeMethod("error", null) }
                }
            },
        )

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        cacheDir = File(b.applicationContext.cacheDir, "kabso_music")
        channel = MethodChannel(b.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        mixer.stop()
        detach()
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        binding = b
        activity = b.activity
        b.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)

    override fun onDetachedFromActivity() {
        binding?.removeActivityResultListener(this)
        binding = null
        activity = null
    }

    private fun attach(): Boolean {
        if (attached) return true
        val controller = FlutterWebRTCPlugin.sharedSingleton?.audioProcessingController ?: return false
        controller.capturePostProcessing.addProcessor(mixer)
        attached = true
        return true
    }

    private fun detach() {
        if (!attached) return
        FlutterWebRTCPlugin.sharedSingleton?.audioProcessingController?.capturePostProcessing?.removeProcessor(mixer)
        attached = false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(result)
            "load" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "path", null)
                    return
                }
                if (!attach()) {
                    result.error("not_ready", "the live microphone is not running", null)
                    return
                }
                try {
                    result.success(mixer.load(path))
                } catch (e: Exception) {
                    Log.w(TAG, "load failed: ${e.javaClass.simpleName}")
                    result.error("unreadable", "the file cannot be decoded", null)
                }
            }
            "play" -> {
                mixer.play()
                result.success(null)
            }
            "pause" -> {
                mixer.pause()
                result.success(null)
            }
            "stop" -> {
                mixer.stop()
                detach()
                result.success(null)
            }
            "setVolume" -> {
                val v = call.argument<Double>("volume") ?: 0.35
                mixer.volume = v.toFloat().coerceIn(0f, 1f)
                result.success(null)
            }
            "setDucking" -> {
                mixer.ducking = call.argument<Boolean>("on") ?: true
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun pick(result: MethodChannel.Result) {
        val a = activity
        if (a == null || pending != null) {
            result.error("busy", "no activity or a pick is open", null)
            return
        }
        pending = result
        val intent =
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "audio/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
        a.startActivityForResult(intent, REQUEST_PICK)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK) return false
        val result = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<Map<String, String>>())
            return true
        }
        val uris = mutableListOf<Uri>()
        data.clipData?.let { clip -> for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri) }
        data.data?.let { if (uris.isEmpty()) uris.add(it) }
        val a = activity
        val dir = cacheDir
        if (a == null || dir == null) {
            result.success(emptyList<Map<String, String>>())
            return true
        }
        Thread({
            val files = mutableListOf<Map<String, String>>()
            dir.mkdirs()
            for (uri in uris) {
                try {
                    val name = displayName(a, uri)
                    val target = File(dir, "${System.nanoTime()}_${safe(name)}")
                    var copied = 0L
                    a.contentResolver.openInputStream(uri)?.use { input ->
                        target.outputStream().use { out ->
                            val buf = ByteArray(64 * 1024)
                            while (true) {
                                val n = input.read(buf)
                                if (n < 0) break
                                copied += n
                                if (copied > MAX_BYTES) throw IllegalStateException("too large")
                                out.write(buf, 0, n)
                            }
                        }
                    }
                    if (copied > 0) files.add(mapOf("path" to target.path, "name" to name)) else target.delete()
                } catch (e: Exception) {
                    Log.w(TAG, "copy failed: ${e.javaClass.simpleName}")
                }
            }
            main.post { result.success(files) }
        }, "kabso-live-music-copy").start()
        return true
    }

    private fun displayName(a: Activity, uri: Uri): String {
        a.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                val name = c.getString(0)
                if (!name.isNullOrBlank()) return name
            }
        }
        return uri.lastPathSegment ?: "audio"
    }

    private fun safe(name: String): String = name.replace(Regex("[^A-Za-z0-9._-]"), "_").takeLast(80)

    companion object {
        const val CHANNEL = "com.kabso/live_music"
        private const val TAG = "KabsoLiveMusic"
        private const val REQUEST_PICK = 0x4B4D
        private const val MAX_BYTES = 50L * 1024 * 1024
    }
}
