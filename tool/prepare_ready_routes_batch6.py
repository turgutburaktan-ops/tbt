"""Reviewed sixth source batch. Run against downloaded page/track/photo directory."""
import json,sys
from pathlib import Path
from prepare_five_province_expansion import build
# slug, city, mode, source km, minutes, displayed difficulty, selected line, endpoints, cover index, mirror
SPECS=[
 ('palu-merkez-yuruyus-parkuru','Elazığ','Yürüyüş',11.2,480,'Zor','Track no. 1','Palu ilçe merkezi','Palu ilçe merkezi dönüş',0,False),
 ('sarili-badempinari-selaleleri-yuruyus-parkuru','Elazığ','Yürüyüş',8.91,240,'Orta','Path','Sarılı köyü','Sarılı köyü dönüş',15,False),
 ('huseynik-olbe-anguzubaba-yuruyus-parkuru','Elazığ','Yürüyüş',12.7,480,'Zor','20011201','Hüseynik','Anguzu Baba Tepesi',0,False),
 ('akpinar-mesire-yeri-macera-parki-yuruyus-parkuru','Elazığ','Yürüyüş',14.4,420,'Zor','Path','Sivrice ilçe merkezi','Sivrice ilçe merkezi dönüş',0,False),
 ('arapgir-merkez-yuruyus-parkuru','Malatya','Yürüyüş',2,120,'Kolay','Arapgir merkez rota','Arapgir çarşı merkezi','Arapgir kültür parkuru bitişi',1,False),
 ('arapgir-eskisehir-vadisi-yuruyus-parkuru','Malatya','Yürüyüş',5,300,'Kolay','Arapgir Eski Şehir','Gözderesi mevkii','Meydan Köprüsü',0,False),
 ('berenge-deresi-yuruyus-parkuru','Malatya','Yürüyüş',10,240,'Kolay','Berenge rota','Arapgir Millet Hanı yakınları','Berenge Deresi parkur bitişi',8,False),
 ('ilicalar-termal-kaplicalar-bisiklet-parkuru','Bingöl','Bisiklet',23.95,240,'Zor','Path','Ekinyolu Kervansaray Kavşağı','Ekinyolu Kervansaray Kavşağı dönüş',0,False),
 ('agaceli-koyu-gulbahar-baraji-bisiklet-parkuru','Bingöl','Bisiklet',21.14,300,'Orta','Path','Ekinyolu Kavşağı','Ekinyolu Kavşağı dönüş',0,False),
 ('nazimiye-dereova-rotasi','Tunceli','Bisiklet',12,120,'Zor','Nazımiye - Dereova Köyü Bisiklet Rotası','Nazımiye ilçe merkezi','Dereova Şelalesi',0,False),
 ('hozat-gozeler-rotasi','Tunceli','Bisiklet',51,420,'Zor','Hozat - Ovacık Gözeler Bisiklet Rotası','Hozat ilçe merkezi','Ovacık Gözeler köyü',0,False),
 ('egil-peygamberler-makami-egil-kalesi-rotasi','Diyarbakır','Yürüyüş',3.7,60,'Kolay','PEYGAMBERLER MAKAMI-EĞİL KALESİ ROTASI- 002','Peygamberler Makamı','Eğil Kalesi',0,False),
 ('cungus-merkez-gezi-rotasi','Diyarbakır','Yürüyüş',1.1,60,'Kolay','ÇÜNGÜŞ MERKEZ GEZİ ROTASI','Çüngüş merkez','Çüngüş merkez dönüş',1,False),
]
TITLES=['Palu merkez kültür yürüyüşü','Sarılı – Badempınarı Şelaleleri yürüyüşü','Hüseynik – Ölbe Vadisi – Anguzu Baba yürüyüşü','Sivrice – Akpınar – Macera Parkı yürüyüşü','Arapgir merkez kültür yürüyüşü','Arapgir Eskişehir Vadisi yürüyüşü','Berenge Deresi yürüyüşü','Ilıcalar Termal Kaplıcaları bisiklet turu','Ağaçeli – Gülbahar Barajı bisiklet turu','Nazımiye – Dereova Şelalesi bisiklet parkuru','Hozat – Ovacık Gözeler bisiklet parkuru','Eğil Peygamberler Makamı – Eğil Kalesi yürüyüşü','Çüngüş merkez kültür yürüyüşü']
NOTES={
 'arapgir-merkez-yuruyus-parkuru':'Kaynak süre aralığı 1–2 saattir; kartta üst sınır gösterilir. ',
 'berenge-deresi-yuruyus-parkuru':'Kaynak süre aralığı 3–4 saattir; kartta üst sınır gösterilir. ',
 'egil-peygamberler-makami-egil-kalesi-rotasi':'KML içinden yalnızca yürüyüş izi alınmıştır; araçla ulaşım yolu dahil değildir. ',
 'hozat-gozeler-rotasi':'Kaynağın Çok zor sınıfı uygulamadaki Zor kategorisinde gösterilir. ',
}
for slug in ['nazimiye-dereova-rotasi','hozat-gozeler-rotasi']:
 NOTES[slug]=NOTES.get(slug,'')+'Kaynak tablosu gidiş-dönüş olarak etiketlenmiş olsa da KML iki farklı noktayı birleştirir. Haritada yalnızca bu tek yönlü iz gösterilir; dönüş eklenmemiştir. Süre kaynak tahminidir. '

def generate(root):
 records,photos=build(root,SPECS,TITLES,NOTES)
 for r in records:
  if r['id'].endswith('hozat_gozeler_rotasi'):
   r['externalSource']['publishedDifficulty']='Çok zor'
   r['dayPlan']['description']=r['dayPlan']['description'].replace('Kaynak zorluğu: Zor.','Kaynak zorluğu: Çok zor.')
 return records,photos
if __name__=='__main__':
 records,photos=generate(Path(sys.argv[1]));out=Path(__file__).resolve().parents[1]/'functions/scripts'
 (out/'ready_routes_batch6.json').write_text(json.dumps(records,ensure_ascii=False,separators=(',',':'))+'\n')
 (out/'ready_route_photos_batch6.json').write_text(json.dumps(photos,ensure_ascii=False,indent=2)+'\n')
