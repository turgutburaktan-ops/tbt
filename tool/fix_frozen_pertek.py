"""Apply one reviewed correction; no crawling, image changes or record removal."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SID = 'wd-q6025389-pertek-kalesi'
FIELDS = {'province': 'Tunceli', 'provinceQid': 'Q620742',
          'district': 'Pertek', 'districtQid': 'Q2540906'}
SOURCE = 'https://www.kulturportali.gov.tr/turkiye/tunceli/gezilecekyer/pertek-kalesi'
DESCRIPTION = ('Pertek Kalesi, Tunceli ilinin Pertek ilçesinde, Keban Baraj Gölü '
               'içinde bir ada üzerindedir. İl ve ilçe bilgisi Kültür Portalı '
               've Pertek Kaymakamlığı ile çapraz kontrol edilmiştir.')


def corrected(text, marker, replacements):
    start = text.index(marker)
    end = text.index('\n  ),', start)
    block = text[start:end]
    for old, new in replacements:
        if old in block:
            assert block.count(old) == 1, old
            block = block.replace(old, new, 1)
        else:
            assert new in block, f'Unexpected frozen data: {old}'
    return text[:start] + block + text[end:]


def changes():
    data = ROOT / 'lib/data'
    places = data / 'verified_travel_places_generated.dart'
    evidence = data / 'spot_coordinate_verification_registry_generated.dart'
    quality = data / 'verified_travel_image_quality_generated.json'
    ptext, etext, qtext = (p.read_text() for p in (places, evidence, quality))
    assert ptext.count('  PhotoSpot(') == 4356
    assert sum(p.read_text().count('PhotoSpot(') for p in data.glob('verified_travel_places*.dart')) == 4507
    newp = corrected(ptext, f"id: '{SID}',", [
        ("city: 'Elazığ'", "city: 'Tunceli'"),
        ("'Elazığ', 'Merkez', 'Kale'", "'Tunceli', 'Pertek', 'Kale'"),
        ('Pertek Kalesi, Merkez ilçesi, Elazığ konumu ve temsil fotoğrafı Wikidata ve HDX/OCHA ilçe sınırıyla doğrulanmış Türkiye gezi ve fotoğraf noktasıdır.', DESCRIPTION),
    ])
    newe = corrected(etext, f"'{SID}': SpotCoordinateVerificationEvidence(", [
        ('Wikidata P625 + HDX COD-AB boundary + Wikidata identity',
         'Wikidata P625 + Kültür Portalı + Pertek Kaymakamlığı'),
        ('province=Q483091:Elazığ / district=Q2963425:Merkez',
         f'province=Q620742:Tunceli / district=Q2540906:Pertek / {SOURCE} / https://www.pertek.gov.tr/pertek-kalesi'),
        ("verifiedAt: 'generated'", "verifiedAt: '2026-09-07'"),
    ])
    oldq = json.loads(qtext)
    assert len(oldq) == 4356
    start = qtext.index(f'"{SID}": {{')
    end = qtext.index('\n  },', start)
    block = qtext[start:end]
    for field, value in FIELDS.items():
        old = json.dumps(oldq[SID][field], ensure_ascii=False)
        new = json.dumps(value, ensure_ascii=False)
        block = block.replace(f'"{field}": {old}', f'"{field}": {new}', 1)
    newq = qtext[:start] + block + qtext[end:]
    parsed = json.loads(newq)
    for sid, meta in oldq.items():
        assert parsed[sid] == (dict(meta, **FIELDS) if sid == SID else meta)
    return [(places, ptext, newp), (evidence, etext, newe), (quality, qtext, newq)]


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    updates = changes()
    if args.check:
        assert all(before == after for _, before, after in updates), 'Correction missing'
    else:
        for path, before, after in updates:
            if before != after:
                path.write_text(after)
    print('PASS: Pertek = Tunceli / Pertek; 4507 catalog records and 4356 generated records retained; image metadata unchanged.')
