from pathlib import Path
import re


path = Path('lib/screens/pro_filter_editor_screen.dart')
text = path.read_text(encoding='utf-8')

if 'TextureSource? _previewTexture;' not in text:
    text = text.replace(
        '  TextureSource? _texture;\n  TextureSource? _thumbTexture;\n',
        '  TextureSource? _texture;\n  TextureSource? _previewTexture;\n  TextureSource? _thumbTexture;\n',
        1,
    )

load_pattern = re.compile(
    r'  Future<void> _load\(\) async \{.*?\n  \}\n\n  GroupShaderConfiguration _buildConfiguration',
    re.S,
)

new_load = r'''  Future<void> _load() async {
    try {
      final file = File(widget.imagePath);
      final fullTexture = await TextureSource.fromFile(file);

      TextureSource previewTexture = fullTexture;
      TextureSource thumbTexture = fullTexture;
      try {
        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final longest = max(decoded.width, decoded.height);
          if (longest > 1280) {
            final scale = 1280 / longest;
            final preview = img.copyResize(
              decoded,
              width: (decoded.width * scale).round(),
              height: (decoded.height * scale).round(),
              interpolation: img.Interpolation.average,
            );
            previewTexture = await TextureSource.fromMemory(
              img.encodeJpg(preview, quality: 90),
            );
          }

          final thumbScale = 220 / longest;
          final thumb = img.copyResize(
            decoded,
            width: max(1, (decoded.width * thumbScale).round()),
            height: max(1, (decoded.height * thumbScale).round()),
            interpolation: img.Interpolation.average,
          );
          thumbTexture = await TextureSource.fromMemory(
            img.encodeJpg(thumb, quality: 80),
          );
        }
      } catch (e) {
        debugPrint('GPU editor preview resize: $e');
      }

      if (!mounted) return;
      setState(() {
        _texture = fullTexture;
        _previewTexture = previewTexture;
        _thumbTexture = thumbTexture;
        _configuration = _buildConfiguration(_looks[_selectedLook]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  GroupShaderConfiguration _buildConfiguration'''

text, count = load_pattern.subn(new_load, text, count=1)
if count != 1:
    raise SystemExit('GPU editor _load block not found')

# Main editor works on the lightweight preview texture. Final export still uses
# _texture (the original full-resolution image) in _exportAndContinue.
main_anchor = '''  Widget _mainPreview() {
    final texture = _texture!;
'''
if main_anchor in text:
    text = text.replace(
        main_anchor,
        '''  Widget _mainPreview() {
    final texture = _previewTexture ?? _texture!;
''',
        1,
    )
elif 'final texture = _previewTexture ?? _texture!;' not in text:
    raise SystemExit('GPU editor main preview anchor not found')

path.write_text(text, encoding='utf-8')
print('GPU editor runtime optimization applied')
