package com.kabso.kabso_live

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.media.AudioAttributes
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * D156: the ring mode (`AudioManager.RINGER_MODE_*`: 0 silent, 1 vibrate,
     * 2 normal), so the launch video plays muted when the phone is silent or
     * on vibrate. Media volume alone would not follow that switch.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kabso/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ringerMode" -> {
                        val audio = getSystemService(AudioManager::class.java)
                        result.success(audio?.ringerMode ?: AudioManager.RINGER_MODE_NORMAL)
                    }
                    else -> result.notImplemented()
                }
            }
        // D243: a live's second camera keeps the screen on (it sits untouched
        // on a stand; a timed-out screen stops the activity and Android takes
        // the camera from an app that is not in the foreground). Only while
        // this window is shown; no permission. D251: answered once, at once,
        // on this (main) thread, never throwing ([ScreenKeepOn]).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kabso/screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "keepOn" -> {
                        val error = ScreenKeepOn.apply(call.arguments, keepOnFlags())
                        if (error == null) result.success(null) else result.error(error, null, null)
                    }
                    else -> result.notImplemented()
                }
            }
        // D223 (CONVENTIONS §10.75): the stable device id for «at most 2
        // accounts created per device». ANDROID_ID is per app-signing key,
        // user and device (Android 8+), survives a reinstall and changes on a
        // factory reset. The app hashes it with a salt before sending; the raw
        // value never leaves the phone. Needs no permission.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kabso/device_id")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "stableId" -> {
                        val id = try {
                            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                        } catch (e: SecurityException) {
                            null
                        }
                        result.success(id)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** D251: this Activity's window flag, or null when it is going away. */
    private fun keepOnFlags(): ScreenKeepOn.Flags? {
        if (isFinishing || isDestroyed) return null
        val target = window ?: return null
        return object : ScreenKeepOn.Flags {
            override fun add() = target.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

            override fun clear() = target.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    /**
     * D152: the two push channels with the owner's sounds (res/raw). A
     * channel's sound is fixed once created (only its name and description
     * follow the language), so new sounds would need new channel ids. Run at
     * every start: creating an existing channel only updates its texts.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val attributes =
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        fun channel(id: String, name: Int, description: Int, sound: String) =
            NotificationChannel(id, getString(name), NotificationManager.IMPORTANCE_HIGH).apply {
                this.description = getString(description)
                setSound(
                    Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/raw/$sound"),
                    attributes,
                )
                enableVibration(true)
            }
        manager.createNotificationChannels(
            listOf(
                channel(
                    "kabso_general",
                    R.string.notification_channel_general,
                    R.string.notification_channel_general_description,
                    "kabi_voice_a",
                ),
                channel(
                    "kabso_messages",
                    R.string.notification_channel_messages,
                    R.string.notification_channel_messages_description,
                    "kabso_message",
                ),
            ),
        )
    }
}
