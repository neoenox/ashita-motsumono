package com.ashita_motsumono

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ashita_motsumono/native_ocr",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "recognizeJapaneseText" -> recognizeJapaneseText(call.argument("path"), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun recognizeJapaneseText(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("NativeOcrInvalidArgument", "画像パスが空です。", null)
            return
        }

        try {
            val imageFile = File(path)
            if (!imageFile.exists()) {
                result.error("NativeOcrFileNotFound", "画像ファイルが見つかりません。", path)
                return
            }

            val image = InputImage.fromFilePath(this, Uri.fromFile(imageFile))
            val recognizer = TextRecognition.getClient(
                JapaneseTextRecognizerOptions.Builder().build(),
            )

            recognizer.process(image)
                .addOnSuccessListener { recognized ->
                    result.success(recognized.text)
                    recognizer.close()
                }
                .addOnFailureListener { e ->
                    result.error("NativeOcrError", e.message ?: e.toString(), e.toString())
                    recognizer.close()
                }
        } catch (e: Exception) {
            result.error("NativeOcrError", e.message ?: e.toString(), e.toString())
        }
    }
}
