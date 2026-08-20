from pathlib import Path
import re


def patch_gradle() -> None:
    candidates = [Path("android/app/build.gradle.kts"), Path("android/app/build.gradle")]
    gradle = next((path for path in candidates if path.exists()), None)
    if gradle is None:
        raise SystemExit("Android app Gradle file not found")

    text = gradle.read_text(encoding="utf-8")
    if "androidx.exifinterface:exifinterface" in text:
        return
    if gradle.suffix == ".kts":
        text += '\n\ndependencies {\n    implementation("androidx.exifinterface:exifinterface:1.3.7")\n}\n'
    else:
        text += "\n\ndependencies {\n    implementation 'androidx.exifinterface:exifinterface:1.3.7'\n}\n"
    gradle.write_text(text, encoding="utf-8")


def patch_main_activity() -> None:
    activities = list(Path("android/app/src/main").rglob("MainActivity.kt"))
    if len(activities) != 1:
        raise SystemExit(f"Expected one MainActivity.kt, found {len(activities)}")
    activity = activities[0]
    current = activity.read_text(encoding="utf-8")
    match = re.search(r"^package\s+([\w.]+)", current, flags=re.MULTILINE)
    if match is None:
        raise SystemExit("MainActivity Kotlin package not found")

    source = r'''package __PACKAGE__

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val photoExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tbt/photo_pipeline"
        ).setMethodCallHandler { call, result ->
            if (call.method != "prepareSharePhoto") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val inputPath = call.argument<String>("inputPath")
            val outputPath = call.argument<String>("outputPath")
            val portraitWidth = call.argument<Int>("portraitWidth") ?: 1440
            val portraitHeight = call.argument<Int>("portraitHeight") ?: 1800
            val quality = call.argument<Int>("quality") ?: 96
            if (inputPath.isNullOrBlank() || outputPath.isNullOrBlank()) {
                result.error("bad_arguments", "Photo paths are required", null)
                return@setMethodCallHandler
            }

            photoExecutor.execute {
                try {
                    val prepared = prepareSharePhoto(
                        inputPath,
                        outputPath,
                        portraitWidth,
                        portraitHeight,
                        quality,
                    )
                    runOnUiThread { result.success(prepared) }
                } catch (error: Throwable) {
                    runOnUiThread {
                        result.error(
                            "photo_pipeline_failed",
                            error.message ?: error.javaClass.simpleName,
                            null,
                        )
                    }
                }
            }
        }
    }

    private fun prepareSharePhoto(
        inputPath: String,
        outputPath: String,
        portraitWidth: Int,
        portraitHeight: Int,
        quality: Int,
    ): String {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(inputPath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw IllegalArgumentException("Captured JPEG could not be decoded")
        }

        var sampleSize = 1
        val longest = max(bounds.outWidth, bounds.outHeight)
        while (longest / sampleSize > 3200) sampleSize *= 2

        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = BitmapFactory.decodeFile(inputPath, options)
            ?: throw IllegalArgumentException("Captured JPEG bitmap is empty")

        val exifOrientation = try {
            ExifInterface(inputPath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (_: Throwable) {
            ExifInterface.ORIENTATION_NORMAL
        }
        val rotation = when (exifOrientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        val oriented = if (rotation == 0f) {
            decoded
        } else {
            Bitmap.createBitmap(
                decoded,
                0,
                0,
                decoded.width,
                decoded.height,
                Matrix().apply { postRotate(rotation) },
                true,
            ).also { decoded.recycle() }
        }

        val portrait = oriented.height >= oriented.width
        val desiredAspect = if (portrait) 4f / 5f else 5f / 4f
        var cropWidth = oriented.width
        var cropHeight = (cropWidth / desiredAspect).roundToInt()
        if (cropHeight > oriented.height) {
            cropHeight = oriented.height
            cropWidth = (cropHeight * desiredAspect).roundToInt()
        }
        cropWidth = cropWidth.coerceIn(1, oriented.width)
        cropHeight = cropHeight.coerceIn(1, oriented.height)
        val cropX = ((oriented.width - cropWidth) / 2).coerceAtLeast(0)
        val cropY = ((oriented.height - cropHeight) / 2).coerceAtLeast(0)
        val cropped = Bitmap.createBitmap(
            oriented,
            cropX,
            cropY,
            cropWidth,
            cropHeight,
        )

        val outputWidth = if (portrait) portraitWidth else portraitHeight
        val outputHeight = if (portrait) portraitHeight else portraitWidth
        val scaled = Bitmap.createScaledBitmap(
            cropped,
            outputWidth,
            outputHeight,
            true,
        )
        File(outputPath).parentFile?.mkdirs()
        FileOutputStream(outputPath).use { stream ->
            if (!scaled.compress(Bitmap.CompressFormat.JPEG, quality, stream)) {
                throw IllegalStateException("JPEG encoder failed")
            }
            stream.flush()
        }

        if (scaled !== cropped) cropped.recycle()
        if (cropped !== oriented) oriented.recycle()
        return outputPath
    }

    override fun onDestroy() {
        photoExecutor.shutdown()
        super.onDestroy()
    }
}
'''.replace("__PACKAGE__", match.group(1))
    activity.write_text(source, encoding="utf-8")


def main() -> None:
    patch_gradle()
    patch_main_activity()
    print("Native 4:5 photo pipeline installed")


if __name__ == "__main__":
    main()
