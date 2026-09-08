import unittest
from datetime import datetime, timezone, timedelta

from import_frozen_shared_catalog import documents
from verify_frozen_shared_catalog import distance, free_license


class FrozenCatalogTests(unittest.TestCase):
    def manifest(self):
        checked = datetime.now(timezone.utc).isoformat()
        row = dict(id='wd-q1-example', name='Örnek', city='Elazığ', district='Merkez',
            lat=38.67, lng=39.22, imageUrl='https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Test.jpg/500px-Test.jpg',
            imageOriginalUrl='https://upload.wikimedia.org/wikipedia/commons/a/ab/Test.jpg',
            imageSourcePage='https://commons.wikimedia.org/wiki/File:Test.jpg', imageAuthor='Test author',
            imageLicense='CC BY-SA 4.0', imageLicenseUrl='https://creativecommons.org/licenses/by-sa/4.0/',
            imageWidth=1600, imageHeight=900, wikidataQid='Q1', provinceQid='Q483091', districtQid='Q2963425', checkedAt=checked)
        return dict(accepted=[row], acceptedCount=1, held=[], frozenTotal=1, checkedAt=checked)

    def test_restrictive_license_cannot_pass(self):
        for license_name, suffix in [('CC BY-NC 4.0', 'by-nc'), ('CC BY-ND 4.0', 'by-nd'), ('CC BY-SA 4.0', 'by-nc-sa')]:
            self.assertFalse(free_license({'LicenseShortName': {'value': license_name},
                'LicenseUrl': {'value': f'https://creativecommons.org/licenses/{suffix}/4.0/'}})[0])

    def test_attribution_license_and_public_domain(self):
        self.assertTrue(free_license({'LicenseShortName': {'value': 'CC BY-SA 4.0'},
            'LicenseUrl': {'value': 'https://creativecommons.org/licenses/by-sa/4.0/'}})[0])
        self.assertTrue(free_license({'LicenseShortName': {'value': 'Public domain'},
            'Copyrighted': {'value': 'False'}})[0])
        for name, path in [('CC BY-SA 2.5', 'by-sa/2.5'), ('CC BY 3.0 pl', 'by/3.0/pl/deed.en')]:
            self.assertTrue(free_license({'LicenseShortName': {'value': name},
                'LicenseUrl': {'value': 'https://creativecommons.org/licenses/'+path}})[0])

    def test_manifest_cannot_silently_drop_held_records(self):
        manifest = self.manifest()
        manifest['frozenTotal'] = 2
        with self.assertRaises(ValueError):
            documents(manifest, 'a'*64, 1)

    def test_publication_keeps_attribution_and_no_invented_rating(self):
        row = documents(self.manifest(), 'a'*64, 1)['wd-q1-example']
        self.assertEqual(row['rating'], 0)
        self.assertEqual(row['imageAuthor'], 'Test author')
        self.assertEqual(row['district'], 'Merkez')
        self.assertTrue(row['coordinateVerified'] and row['imageVerified'])

    def test_bad_preview_resolution_count_and_stale_proof_rejected(self):
        invalid = []
        for field, value in [('imageUrl', 'https://upload.wikimedia.org.evil.test/a.jpg'),
                             ('imageWidth', 1599), ('lat', 0), ('district', '')]:
            manifest = self.manifest()
            manifest['accepted'][0][field] = value
            invalid.append(manifest)
        old = self.manifest()
        old['checkedAt'] = (datetime.now(timezone.utc)-timedelta(days=2)).isoformat()
        invalid.append(old)
        for manifest in invalid:
            with self.assertRaises(ValueError):
                documents(manifest, 'a'*64, 1)
        with self.assertRaises(ValueError):
            documents(self.manifest(), 'a'*64, 2)

    def test_eighteen_meter_duplicates_include_different_names(self):
        a = {'lat': 38, 'lng': 39}
        self.assertLess(distance(a, {'lat': 38.0001, 'lng': 39}), 18)
        self.assertGreater(distance(a, {'lat': 38.0002, 'lng': 39}), 18)


if __name__ == '__main__':
    unittest.main()
