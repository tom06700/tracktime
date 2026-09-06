package com.thomasgomez.tracktime

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private val permissionRequest = 902

    private fun notificationStatus(): String {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            val asked = getPreferences(MODE_PRIVATE).getBoolean("notificationAsked", false)
            return if (asked) "denied" else "notDetermined"
        }
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        return if (Build.VERSION.SDK_INT < 24 || manager.areNotificationsEnabled()) "authorized" else "denied"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nitrate/notification_permission")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(notificationStatus())
                    "request" -> {
                        if (permissionResult != null) {
                            result.error("BUSY", "A permission request is already active", null)
                        } else if (notificationStatus() != "notDetermined" || Build.VERSION.SDK_INT < 33) {
                            result.success(notificationStatus())
                        } else {
                            permissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), permissionRequest)
                        }
                    }
                    "openSettings" -> {
                        try {
                            val intent = if (Build.VERSION.SDK_INT >= 26) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) { result.success(false) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequest) {
            // A dismissed prompt has no result; retain the undetermined state.
            if (grantResults.isNotEmpty()) {
                getPreferences(MODE_PRIVATE).edit().putBoolean("notificationAsked", true).apply()
            }
            permissionResult?.success(notificationStatus())
            permissionResult = null
        }
    }

    override fun onDestroy() {
        permissionResult?.error("CANCELLED", "Activity closed", null)
        permissionResult = null
        super.onDestroy()
    }
}
