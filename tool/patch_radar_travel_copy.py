from pathlib import Path

path = Path('lib/screens/radar_screen.dart')
text = path.read_text(encoding='utf-8')

replacements = {
    "'Çekim fırsatları'": "'Gezilecek yerler'",
    "'Türkiye genelinden güçlü noktalar'": "'Türkiye genelinden görülmeye değer yerler'",
    "'${_cityController.text.trim()} için güçlü noktalar'": "'${_cityController.text.trim()} için görülmeye değer yerler'",
    "'$spots çekim fırsatı'": "'$spots gezilecek yer'",
}

changed = False
for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new)
        changed = True

if not changed:
    raise SystemExit('Radar travel copy anchors not found')

path.write_text(text, encoding='utf-8')
print('Radar travel copy updated')
