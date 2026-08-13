from pathlib import Path


def main() -> None:
    camera = Path('lib/screens/camera_screen.dart')
    text = camera.read_text()

    old_widget = """class CameraScreen extends StatefulWidget {\n  const CameraScreen({super.key});\n\n  @override\n  State<CameraScreen> createState() => _CameraScreenState();\n}\n"""
    new_widget = """class CameraScreen extends StatefulWidget {\n  final String? referenceImageUrl;\n  final String? referenceTitle;\n  final String? referenceGuide;\n\n  const CameraScreen({\n    super.key,\n    this.referenceImageUrl,\n    this.referenceTitle,\n    this.referenceGuide,\n  });\n\n  @override\n  State<CameraScreen> createState() => _CameraScreenState();\n}\n"""
    if old_widget in text:
        text = text.replace(old_widget, new_widget, 1)

    state_marker = "  bool _subjectLocked = false;\n"
    if state_marker in text and "_showReferenceOverlay" not in text:
        text = text.replace(state_marker, state_marker + "  bool _showReferenceOverlay = true;\n", 1)

    preview_marker = """            if (_showGrid)\n              const IgnorePointer(child: _CameraGrid()),\n"""
    overlay = """            if (widget.referenceImageUrl != null &&\n                widget.referenceImageUrl!.isNotEmpty &&\n                _showReferenceOverlay)\n              Positioned.fill(\n                child: IgnorePointer(\n                  child: Opacity(\n                    opacity: .30,\n                    child: Image.network(\n                      widget.referenceImageUrl!,\n                      fit: BoxFit.cover,\n                      filterQuality: FilterQuality.low,\n                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),\n                    ),\n                  ),\n                ),\n              ),\n            if (widget.referenceImageUrl != null && widget.referenceImageUrl!.isNotEmpty)\n              Positioned(\n                left: 10,\n                bottom: 10,\n                child: GestureDetector(\n                  onTap: () => setState(() => _showReferenceOverlay = !_showReferenceOverlay),\n                  child: Container(\n                    constraints: const BoxConstraints(maxWidth: 250),\n                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),\n                    decoration: BoxDecoration(\n                      color: Colors.black.withOpacity(.72),\n                      borderRadius: BorderRadius.circular(14),\n                      border: Border.all(color: Colors.white12),\n                    ),\n                    child: Row(\n                      mainAxisSize: MainAxisSize.min,\n                      children: [\n                        Icon(\n                          _showReferenceOverlay ? Icons.layers : Icons.layers_clear,\n                          size: 17,\n                          color: const Color(0xFFFFC107),\n                        ),\n                        const SizedBox(width: 7),\n                        Flexible(\n                          child: Text(\n                            _showReferenceOverlay\n                                ? (widget.referenceGuide ?? 'Referans kadrajı eşleştir')\n                                : 'Referansı göster',\n                            maxLines: 2,\n                            overflow: TextOverflow.ellipsis,\n                            style: const TextStyle(\n                              color: Colors.white,\n                              fontSize: 10.5,\n                              fontWeight: FontWeight.w700,\n                            ),\n                          ),\n                        ),\n                      ],\n                    ),\n                  ),\n                ),\n              ),\n            if (_showGrid)\n              const IgnorePointer(child: _CameraGrid()),\n"""
    if preview_marker in text and "widget.referenceImageUrl" not in text[text.find('Widget _buildPreview()'):]:
        text = text.replace(preview_marker, overlay, 1)

    camera.write_text(text)

    detail = Path('lib/screens/spot_detail_screen.dart')
    d = detail.read_text()
    old_route = "MaterialPageRoute(builder: (_) => const CameraScreen()),"
    new_route = """MaterialPageRoute(\n                            builder: (_) => CameraScreen(\n                              referenceImageUrl: spot.imageUrl,\n                              referenceTitle: spot.name,\n                              referenceGuide: '${spot.recommendedLens} • ${spot.angle}',\n                            ),\n                          ),"""
    if old_route in d:
        d = d.replace(old_route, new_route, 1)
    d = d.replace("'Bu Noktada Fotoğraf Çek'", "'AI Koç ile Aynı Kadrajı Çek'", 1)
    detail.write_text(d)

    print('Fast reference framing coach applied')


if __name__ == '__main__':
    main()
