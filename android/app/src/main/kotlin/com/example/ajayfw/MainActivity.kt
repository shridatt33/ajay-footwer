package com.example.ajayfw

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.ajayfw/qr_gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidSdk" -> {
                        result.success(Build.VERSION.SDK_INT)
                    }
                    "saveQrToGallery" -> {
                        try {
                            val imageBytes = call.argument<ByteArray>("imageBytes")
                            val productId = call.argument<String>("productId") ?: "product"

                            if (imageBytes == null || imageBytes.isEmpty()) {
                                result.error(
                                    "INVALID_IMAGE",
                                    "No QR image bytes were supplied.",
                                    null,
                                )
                                return@setMethodCallHandler
                            }

                            val saved = saveQrToGallery(imageBytes, productId)
                            result.success(saved)
                        } catch (e: Exception) {
                            result.error(
                                "SAVE_FAILED",
                                e.message ?: "Failed to save QR code to Gallery.",
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveQrToGallery(imageBytes: ByteArray, productId: String): Boolean {
        val safeProductId = productId.replace(Regex("[^A-Za-z0-9._-]"), "_").ifBlank { "product" }
        val fileName = "QR_${safeProductId}.png"

        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return false

        contentResolver.openOutputStream(uri)?.use { outputStream ->
            outputStream.write(imageBytes)
            outputStream.flush()
        } ?: return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        }

        return true
    }
}
