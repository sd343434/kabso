package com.kabso.kabso_camera_fx

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * D144: the Dart side of [CameraFxProcessor] (`com.kabso/camera_fx`).
 *
 * The plugin keeps what was asked (colour, licence, effect), so a processor
 * created later — a new track, a recreated Activity — starts with it.
 *
 * ActivityAware because DeepAR validates its licence through a WebView and
 * needs a UI context; with the application context it silently never
 * initializes.
 *
 * The licence key arrives over the channel from a `--dart-define`; it is never
 * logged and never written anywhere.
 *
 * D144a: DeepAR's state goes back to Dart as `status` calls on the same
 * channel (`{state, reason}`), and `diagnostics` answers the non-release
 * overlay's poll (counters and state, never the key). The camera/microphone
 * permission helper ([KabsoPermissions]) has its own channel.
 */
class KabsoCameraFxPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var permissionsChannel: MethodChannel? = null
    private val permissions = KabsoPermissions()
    private var activityBinding: ActivityPluginBinding? = null
    private val main = Handler(Looper.getMainLooper())
    private var activity: Activity? = null

    /** The last DeepAR status, kept across processors (Dart may ask). */
    private var lastStatus: Map<String, Any?> = mapOf("state" to "off", "reason" to null)
    private var processor: CameraFxProcessor? = null
    private var attachedTrack: LocalVideoTrack? = null

    private var licenseKey: String? = null
    private var colorMatrix: FloatArray? = null
    private var effect: DeepArStage.Effect? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        permissionsChannel = MethodChannel(binding.binaryMessenger, KabsoPermissions.CHANNEL).also {
            it.setMethodCallHandler(permissions::handle)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        permissionsChannel?.setMethodCallHandler(null)
        permissionsChannel = null
        releaseProcessor()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        bindActivity(binding)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        bindActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // DeepAR holds the old Activity: drop the processor; the next attach
        // builds a new one with the same colour and effect.
        releaseProcessor()
        unbindActivity()
    }

    override fun onDetachedFromActivity() {
        releaseProcessor()
        unbindActivity()
    }

    private fun bindActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        permissions.activity = binding.activity
        binding.addRequestPermissionsResultListener(permissions)
    }

    private fun unbindActivity() {
        activityBinding?.removeRequestPermissionsResultListener(permissions)
        activityBinding = null
        permissions.cancelPending()
        permissions.activity = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attach" -> result.success(attach(call.argument<String>("trackId")))
            "setColorMatrix" -> {
                val values = call.argument<List<Double>>("matrix")
                colorMatrix = values?.takeIf { it.size == 12 }?.map { it.toFloat() }?.toFloatArray()
                processor?.setColorMatrix(colorMatrix)
                result.success(null)
            }
            "setLicenseKey" -> {
                val key = call.argument<String>("licenseKey")
                if (key.isNullOrEmpty()) {
                    result.success(false)
                    return
                }
                licenseKey = key
                processor?.setLicenseKey(key)
                result.success(true)
            }
            "setEffect" -> {
                effect = call.argument<String>("effect")?.let(::resolveEffect)
                processor?.setEffect(effect)
                result.success(null)
            }
            "diagnostics" -> {
                val diagnostics = processor?.diagnostics() ?: (lastStatus + mapOf(
                    "licencePresent" to !licenseKey.isNullOrEmpty(),
                    "attached" to false,
                ))
                result.success(diagnostics + mapOf("attached" to (attachedTrack != null)))
            }
            "status" -> result.success(lastStatus)
            "release" -> {
                releaseProcessor()
                colorMatrix = null
                effect = null
                lastStatus = mapOf("state" to "off", "reason" to null)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun attach(trackId: String?): Boolean {
        val host = activity ?: return false
        if (trackId.isNullOrEmpty()) return false
        val webrtc = FlutterWebRTCPlugin.sharedSingleton ?: return false
        val track = webrtc.getLocalTrack(trackId) as? LocalVideoTrack
        if (track == null) {
            Log.w(TAG, "attach: no local video track with that id")
            return false
        }
        if (track === attachedTrack) return true
        val current = processor ?: CameraFxProcessor(host, ::onStatus).also { created ->
            licenseKey?.let(created::setLicenseKey)
            created.setColorMatrix(colorMatrix)
            created.setEffect(effect)
            processor = created
        }
        attachedTrack?.let { previous -> current.detachFrom(previous) }
        track.addProcessor(current)
        attachedTrack = track
        return true
    }

    /** Any thread: DeepAR's state changed; Dart hears it on the main thread. */
    private fun onStatus(status: Map<String, Any?>) {
        main.post {
            lastStatus = status
            channel?.invokeMethod("status", status)
        }
    }

    /** Asset keys become the APK asset path Flutter stored them under. */
    private fun resolveEffect(effect: String): DeepArStage.Effect =
        if (effect.startsWith(BUILTIN)) {
            DeepArStage.Effect.Builtin(effect.removePrefix(BUILTIN))
        } else {
            DeepArStage.Effect.Asset(
                FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(effect),
            )
        }

    private fun releaseProcessor() {
        val current = processor ?: return
        attachedTrack?.let { current.detachFrom(it) }
        attachedTrack = null
        processor = null
        current.dispose()
    }

    private companion object {
        const val TAG = "KabsoCameraFx"
        const val CHANNEL = "com.kabso/camera_fx"
        const val BUILTIN = "builtin:"
    }
}
