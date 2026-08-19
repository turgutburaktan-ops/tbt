from pathlib import Path
import glob


def find_iris_root() -> Path:
    matches = sorted(glob.glob(str(Path.home() / '.pub-cache/hosted/pub.dev/iris_camera-*')))
    if not matches:
        raise SystemExit('iris_camera package cache not found')
    return Path(matches[-1])


def patch_controller(root: Path) -> None:
    path = root / 'android/src/main/kotlin/com/anies1212/iris_camera/CameraController.kt'
    text = path.read_text(encoding='utf-8')
    if 'suspend fun switchLensById(' in text:
        return

    marker = '''    suspend fun initialize() {
'''
    method = '''    suspend fun switchLensById(descriptorId: String): CameraLensDescriptorNative {
        val lenses = listAvailableLenses(includeFront = true)
        val target = lenses.firstOrNull { it.id == descriptorId }
            ?: throw IllegalArgumentException("Camera lens id not found: $descriptorId")
        selectedLensId = target.id
        selectedDescriptor = target
        bindUseCases()
        stateStreamHandler.emit(CameraLifecycleStateNative.RUNNING)
        return target
    }

'''
    if marker not in text:
        raise SystemExit('Iris initialize marker not found')
    text = text.replace(marker, method + marker, 1)
    path.write_text(text, encoding='utf-8')


def patch_plugin(root: Path) -> None:
    path = root / 'android/src/main/kotlin/com/anies1212/iris_camera/IrisCameraPlugin.kt'
    text = path.read_text(encoding='utf-8')
    if '"switchLensById" ->' in text:
        return

    marker = '''            "takePhoto" -> launchWithPermission(result) {
'''
    block = '''            "switchLensById" -> launchWithPermission(result) {
                val lensId = call.argument<String>("id")
                    ?: return@launchWithPermission result.error(
                        "invalid_arguments",
                        "Expected lens id",
                        null,
                    )
                val descriptor = cameraController?.switchLensById(lensId)
                result.success(descriptor?.toMap())
            }

'''
    if marker not in text:
        raise SystemExit('Iris takePhoto marker not found')
    text = text.replace(marker, block + marker, 1)
    path.write_text(text, encoding='utf-8')


def main() -> None:
    root = find_iris_root()
    patch_controller(root)
    patch_plugin(root)
    print(f'Iris direct lens ID switching patch applied to {root.name}')


if __name__ == '__main__':
    main()
