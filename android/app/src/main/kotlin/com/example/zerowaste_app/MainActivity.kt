package com.example.zerowaste_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.zerowaste_app/notifications"
    private val CHANNEL_ID = "zerowaste_notifications"
    private val CHANNEL_NAME = "ZeroWaste Notifications"
    private val CHANNEL_DESCRIPTION = "Notifications for ZeroWaste app"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        try {
            // Create notification channel
            createNotificationChannel()

            // Set up method channel
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        try {
                            // Channel is already created, just return success
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error initializing notifications", e)
                            result.error("INIT_ERROR", "Failed to initialize notifications", e.message)
                        }
                    }
                    "showNotification" -> {
                        try {
                            val title = call.argument<String>("title")
                            val body = call.argument<String>("body")
                            val payload = call.argument<String>("payload")

                            if (title == null || body == null) {
                                result.error("INVALID_ARGUMENTS", "Title and body are required", null)
                                return@setMethodCallHandler
                            }

                            showNotification(title, body, payload)
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error showing notification", e)
                            result.error("NOTIFICATION_ERROR", "Failed to show notification", e.message)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error configuring Flutter engine", e)
        }
    }

    private fun createNotificationChannel() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = CHANNEL_DESCRIPTION
                }

                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error creating notification channel", e)
        }
    }

    private fun showNotification(title: String, body: String, payload: String?) {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                if (payload != null) {
                    putExtra("payload", payload)
                }
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(System.currentTimeMillis().toInt(), notification)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error showing notification", e)
        }
    }
}
