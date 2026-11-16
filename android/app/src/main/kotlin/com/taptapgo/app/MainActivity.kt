package com.taptapgo.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createJobsChannel()
    }

    // Push notifications (new job, new trip) use this channel. High importance makes them
    // pop up on screen with sound, like a ride-hailing app. The server names it in every
    // push (FcmClient), and the manifest makes it the default.
    private fun createJobsChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "taptapgo_jobs",
            "Jobs and trips",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "New jobs, trips and changes to them"
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }
}
