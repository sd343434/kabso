package com.kabso.kabso_live

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
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
