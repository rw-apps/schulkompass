package com.example.app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException


class MainActivity: FlutterActivity() {
    private val createFileCode = 1404
    private val confirmDeviceCode = 1405
    private var filePath = ""

    /// Wartet auf die Bestätigung mit Geräte-PIN/Muster/Biometrie
    /// (DEVICE_AUTH_CHANNEL, device_auth.dart).
    private var pendingConfirm: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveFile" -> {
                    filePath = call.argument<String>("filePath").toString()
                    createFile(call.argument<String>("fileName").toString(), call.argument<String>("mimeType").toString())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Geräte-Anmeldung vor sensiblen Schritten (Sicherheitsprüfung
        // 03.11.26: Geräteübertragung gab alle Passwörter ohne erneute
        // Bestätigung heraus). KeyguardManager statt local_auth: kein neues
        // Plugin, kein Umbau auf FlutterFragmentActivity. Ergebnis:
        // "ok" | "cancel" | "none" (keine Displaysperre eingerichtet).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_AUTH_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "confirm") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (!km.isDeviceSecure) {
                result.success("none")
                return@setMethodCallHandler
            }
            @Suppress("DEPRECATION")
            val intent = km.createConfirmDeviceCredentialIntent(
                call.argument<String>("title"),
                call.argument<String>("text"),
            )
            if (intent == null) {
                result.success("none")
                return@setMethodCallHandler
            }
            pendingConfirm?.success("cancel")
            pendingConfirm = result
            @Suppress("DEPRECATION")
            startActivityForResult(intent, confirmDeviceCode)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            confirmDeviceCode -> {
                pendingConfirm?.success(if (resultCode == Activity.RESULT_OK) "ok" else "cancel")
                pendingConfirm = null
            }
            createFileCode -> {
                data?.data?.let { uri ->
                    try {
                        contentResolver.openFileDescriptor(uri, "w")?.use {
                            FileInputStream(filePath).use { inputStream ->
                                FileOutputStream(it.fileDescriptor).use { outputStream ->
                                    inputStream.copyTo(outputStream)
                                }
                            }
                        }
                    } catch (e: FileNotFoundException) {
                        e.printStackTrace()
                    } catch (e: IOException) {
                        e.printStackTrace()
                    }
                }
            }
        }
    }

    private fun createFile(fileName: String, mimeType: String) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        startActivityForResult(intent, createFileCode)
    }

    companion object {
        private const val STORAGE_CHANNEL = "io.github.lanis-mobile/storage"
        private const val DEVICE_AUTH_CHANNEL = "schulportal/device_auth"
    }
}
