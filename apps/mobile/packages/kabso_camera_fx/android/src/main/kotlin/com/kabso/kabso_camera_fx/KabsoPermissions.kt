package com.kabso.kabso_camera_fx

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * D144a: camera and microphone permissions for going live, on channel
 * `com.kabso/permissions` — so the app can explain first, ask the system
 * once, and send a person who refused for good to the app's settings
 * (flutter_webrtc would otherwise ask on its own, every time).
 *
 * Per permission (`camera`, `microphone`):
 * - `granted`;
 * - `notAsked`: never asked by this app (the system prompt will show);
 * - `denied`: refused, the system will still ask again;
 * - `blocked`: refused for good ("don't ask again", or refused twice on
 *   Android 11+): only the app's settings can change it.
 *
 * Android cannot tell "never asked" from "blocked" by itself (both answer
 * no rationale), so the first request is remembered in this app's
 * preferences.
 */
internal class KabsoPermissions : PluginRegistry.RequestPermissionsResultListener {
    var activity: Activity? = null

    private var pending: Pending? = null

    private class Pending(val kinds: List<String>, val result: MethodChannel.Result)

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val host = activity
        if (host == null) {
            result.error("no_activity", "no activity", null)
            return
        }
        val kinds = call.argument<List<String>>("kinds").orEmpty().filter { it in PERMISSIONS }
        when (call.method) {
            "status" -> result.success(kinds.associateWith { status(host, it, afterRequest = false) })
            "request" -> request(host, kinds, result)
            "openSettings" -> result.success(openSettings(host))
            else -> result.notImplemented()
        }
    }

    private fun request(host: Activity, kinds: List<String>, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "a request is already showing", null)
            return
        }
        val missing = kinds.filter {
            host.checkSelfPermission(PERMISSIONS.getValue(it)) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(kinds.associateWith { GRANTED })
            return
        }
        prefs(host).edit().apply { missing.forEach { putBoolean(it, true) } }.apply()
        pending = Pending(kinds, result)
        host.requestPermissions(missing.map { PERMISSIONS.getValue(it) }.toTypedArray(), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val done = pending ?: return true
        pending = null
        val host = activity
        if (host == null) {
            done.result.error("no_activity", "no activity", null)
            return true
        }
        done.result.success(done.kinds.associateWith { status(host, it, afterRequest = true) })
        return true
    }

    /** The activity went away with the system prompt open. */
    fun cancelPending() {
        pending?.result?.error("no_activity", "activity detached", null)
        pending = null
    }

    private fun status(host: Activity, kind: String, afterRequest: Boolean): String {
        val permission = PERMISSIONS.getValue(kind)
        if (host.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) return GRANTED
        if (host.shouldShowRequestPermissionRationale(permission)) return DENIED
        // No rationale: never asked, or refused for good.
        val asked = afterRequest || prefs(host).getBoolean(kind, false)
        return if (asked) BLOCKED else NOT_ASKED
    }

    private fun openSettings(host: Activity): Boolean = try {
        host.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", host.packageName, null))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        true
    } catch (_: Exception) {
        false
    }

    private fun prefs(host: Activity) =
        host.getSharedPreferences("kabso_permissions", Context.MODE_PRIVATE)

    companion object {
        const val CHANNEL = "com.kabso/permissions"
        private const val REQUEST_CODE = 0x4b50 // "KP"
        private const val GRANTED = "granted"
        private const val DENIED = "denied"
        private const val BLOCKED = "blocked"
        private const val NOT_ASKED = "notAsked"
        private val PERMISSIONS = mapOf(
            "camera" to Manifest.permission.CAMERA,
            "microphone" to Manifest.permission.RECORD_AUDIO,
        )
    }
}
