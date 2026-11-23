package com.example.ajayfw

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
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

                            val saved = saveMediaToGallery(imageBytes, productId, "image/png", Environment.DIRECTORY_PICTURES)
                            result.success(saved)
                        } catch (e: Exception) {
                            result.error(
                                "SAVE_FAILED",
                                e.message ?: "Failed to save QR code to Gallery.",
                                null,
                            )
                        }
                    }
                    "savePdfToDownloads" -> {
                        try {
                            val fileBytes = call.argument<ByteArray>("fileBytes")
                            val fileName = call.argument<String>("fileName") ?: "product.pdf"

                            if (fileBytes == null || fileBytes.isEmpty()) {
                                result.error(
                                    "INVALID_PDF",
                                    "No PDF bytes were supplied.",
                                    null,
                                )
                                return@setMethodCallHandler
                            }

                            val saved = saveMediaToDownloads(fileBytes, fileName, "application/pdf")
                            result.success(saved)
                        } catch (e: Exception) {
                            result.error(
                                "SAVE_FAILED",
                                e.message ?: "Failed to save PDF to Downloads.",
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveMediaToGallery(
        imageBytes: ByteArray,
        productId: String,
        mimeType: String,
        relativePath: String,
    ): Boolean {
        val safeProductId = productId.replace(Regex("[^A-Za-z0-9._-]"), "_").ifBlank { "product" }
        val fileName = "QR_${safeProductId}.png"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                put(MediaStore.Images.Media.RELATIVE_PATH, relativePath)
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }

            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: return false

            contentResolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(imageBytes)
                outputStream.flush()
            } ?: return false

            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return true
        }

        val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        if (!picturesDir.exists()) {
            picturesDir.mkdirs()
        }

        val file = File(picturesDir, fileName)
        file.writeBytes(imageBytes)
        return true
    }

    private fun saveMediaToDownloads(
        fileBytes: ByteArray,
        fileName: String,
        mimeType: String,
    ): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return false

            contentResolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(fileBytes)
                outputStream.flush()
            } ?: return false

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return true
        }

        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloadsDir.exists()) {
            downloadsDir.mkdirs()
        }

        val file = File(downloadsDir, fileName)
        file.writeBytes(fileBytes)
        return true
    }
}
