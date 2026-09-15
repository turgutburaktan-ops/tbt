import unittest
from extract_overture_cafes import candidate

class TestCandidate(unittest.TestCase):
    def feature(self, **changes):
        p=dict(id='12345678-abcd',names={'primary':'Örnek Kafe'},basic_category='cafe',
               confidence=.95,addresses=[{'country':'TR'}])
        p.update(changes)
        return {'properties':p,'geometry':{'type':'Point','coordinates':[39.22,38.67]}}
    def test_valid(self):
        self.assertEqual(candidate(self.feature())['source'],'overture')
    def test_rejects_bad_or_closed_places(self):
        for changes in [dict(confidence=.3),dict(confidence=float('nan')),dict(operating_status='permanently_closed'),
                        dict(addresses=[{'country':'DE'}]),dict(basic_category='internet_cafe'),dict(id='../bad')]:
            self.assertIsNone(candidate(self.feature(**changes)))
    def test_old_and_new_taxonomy(self):
        self.assertIsNotNone(candidate(self.feature(basic_category=None,categories={'primary':'coffee_shop'})))
        self.assertIsNotNone(candidate(self.feature(basic_category=None,taxonomy={'hierarchy':['food_and_drink','cafe']})))

if __name__=='__main__': unittest.main()
