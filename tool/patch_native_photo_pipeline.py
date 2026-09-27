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
import android.view.KeyEvent
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
    private var cameraControlsChannel: MethodChannel? = null
    private var cameraShutterActive = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cameraControlsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tbt/camera_controls"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "setActive") {
                    cameraShutterActive = call.argument<Boolean>("active") == true
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }

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
            val portraitWidth = call.argument<Int>("portraitWidth") ?: 2160
            val portraitHeight = call.argument<Int>("portraitHeight") ?: 2700
            val quality = call.argument<Int>("quality") ?: 98
            val maxDecodeDimension = call.argument<Int>("maxDecodeDimension") ?: 4600
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
                        maxDecodeDimension,
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

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val isVolumeKey = event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        if (cameraShutterActive && isVolumeKey) {
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                cameraControlsChannel?.invokeMethod("volumeShutter", null)
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    private fun prepareSharePhoto(
        inputPath: String,
        outputPath: String,
        portraitWidth: Int,
        portraitHeight: Int,
        quality: Int,
        maxDecodeDimension: Int,
    ): String {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(inputPath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw IllegalArgumentException("Captured JPEG could not be decoded")
        }

        var sampleSize = 1
        val longest = max(bounds.outWidth, bounds.outHeight)
        // Keep a normal 12/16 MP sensor frame at native resolution. Very large
        // 48/64 MP binned sources are sampled only enough to stay memory-safe.
        while (longest / sampleSize > maxDecodeDimension) sampleSize *= 2

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
        val portraitAspect = portraitWidth.toFloat() / portraitHeight.toFloat()
        val desiredAspect = if (portrait) portraitAspect else 1f / portraitAspect
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
        cameraShutterActive = false
        cameraControlsChannel?.setMethodCallHandler(null)
        cameraControlsChannel = null
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
