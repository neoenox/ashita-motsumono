package com.ashita_motsumono

import android.net.Uri
import android.webkit.MimeTypeMap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ashita_motsumono/share_file_staging",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "copyContentUriToStaging" -> copyContentUriToStaging(call, result)
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

    private fun copyContentUriToStaging(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val uriText = call.argument<String>("uri")
        val destinationPath = call.argument<String>("destinationDirectory")
        val requestedExtension = call.argument<String>("extension")
        val mimeType = call.argument<String>("mimeType")
        val maxBytes = call.argument<Number>("maxBytes")?.toLong()

        if (uriText.isNullOrBlank() || destinationPath.isNullOrBlank()) {
            result.error(
                "ShareFileInvalidArgument",
                "共有ファイルのURIまたは保存先が空です。",
                null,
            )
            return
        }

        var destinationFile: File? = null
        try {
            val uri = Uri.parse(uriText)
            if (uri.scheme != "content") {
                result.error(
                    "ShareFileUnsupportedUri",
                    "content URI以外はネイティブコピー対象外です。",
                    uriText,
                )
                return
            }

            val destinationDirectory = File(destinationPath).canonicalFile
            val cacheRoot = cacheDir.canonicalFile
            val allowed = destinationDirectory == cacheRoot ||
                destinationDirectory.path.startsWith(cacheRoot.path + File.separator)
            if (!allowed) {
                result.error(
                    "ShareFileInvalidDestination",
                    "共有ファイルの保存先がキャッシュ領域外です。",
                    destinationDirectory.path,
                )
                return
            }
            if (!destinationDirectory.exists() && !destinationDirectory.mkdirs()) {
                result.error(
                    "ShareFileCreateDirectoryFailed",
                    "共有ファイルの保存先を作成できませんでした。",
                    destinationDirectory.path,
                )
                return
            }

            val extension = normalizedExtension(requestedExtension, mimeType)
            val outputFile = File(destinationDirectory, "${UUID.randomUUID()}$extension")
            destinationFile = outputFile

            val input = contentResolver.openInputStream(uri)
            if (input == null) {
                result.error(
                    "ShareFileOpenFailed",
                    "共有ファイルを開けませんでした。",
                    uriText,
                )
                return
            }

            input.use { source ->
                outputFile.outputStream().buffered().use { target ->
                    val buffer = ByteArray(8 * 1024)
                    var copied = 0L
                    while (true) {
                        val read = source.read(buffer)
                        if (read < 0) break
                        copied += read
                        if (maxBytes != null && copied > maxBytes) {
                            throw ShareFileTooLargeException()
                        }
                        target.write(buffer, 0, read)
                    }
                    target.flush()
                }
            }

            if (outputFile.length() <= 0L) {
                outputFile.delete()
                result.error(
                    "ShareFileEmpty",
                    "共有ファイルが空です。",
                    uriText,
                )
                return
            }

            result.success(outputFile.path)
        } catch (e: ShareFileTooLargeException) {
            destinationFile?.delete()
            result.error(
                "ShareFileTooLarge",
                "共有ファイルのサイズが上限を超えています。",
                maxBytes,
            )
        } catch (e: SecurityException) {
            destinationFile?.delete()
            result.error(
                "ShareFilePermissionDenied",
                "共有ファイルを読み取る権限がありません。",
                e.toString(),
            )
        } catch (e: Exception) {
            destinationFile?.delete()
            result.error(
                "ShareFileCopyFailed",
                e.message ?: "共有ファイルのコピーに失敗しました。",
                e.toString(),
            )
        }
    }

    private fun normalizedExtension(
        requestedExtension: String?,
        mimeType: String?,
    ): String {
        val requested = requestedExtension?.lowercase()
        if (requested != null && requested.matches(Regex("^\\.[a-z0-9]{1,10}$"))) {
            return requested
        }

        val fromMime = mimeType
            ?.takeUnless { it.endsWith("/*") }
            ?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
            ?.lowercase()
        if (!fromMime.isNullOrBlank() && fromMime.matches(Regex("^[a-z0-9]{1,10}$"))) {
            return ".$fromMime"
        }
        return ".bin"
    }

    private class ShareFileTooLargeException : Exception()
}
