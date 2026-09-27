"""Build the second reviewed neighboring-province batch from source downloads."""
import json,math,hashlib,sys,urllib.parse
from pathlib import Path
from prepare_nearby_ready_routes import selected_points
from prepare_elazig_external_routes import meters

# slug, city, mode, source km, source minutes, difficulty, selected track, start, end, cover index
SPECS=[
 ('malatya-merkez-yuruyus-parkuru','Malatya','Yürüyüş',7,300,'Kolay','Malatya Rotası','Kernek Meydanı','Malatya kültür parkuru bitişi',1),
 ('yesilyurt-yuruyus-parkuru','Malatya','Yürüyüş',4,240,'Kolay','Yeşilyurt Rotası','Yeşilyurt Gedik','Yeşilyurt kültür parkuru bitişi',0),
 ('girmana-kanyonu-yuruyus-parkuru','Malatya','Yürüyüş',2,120,'Kolay','Yürüyüş Yolu','Girmana Kanyonu otoparkı','Girmana parkuru bitişi',0),
 ('merkez-anafatma-rotasi','Tunceli','Bisiklet',10,60,'Kolay','Cumhuriyet Mah. - Ana Fatma Bisiklet Rotası','Tunceli Kent Ormanı','Munzur Vadisi Ziyaretçi Tanıtım Merkezi',0),
 ('merkez-kutuderesi-rotasi','Tunceli','Bisiklet',20,120,'Kolay','Cemevi - Kutudere Bisiklet Rotası','Tunceli Cemevi','Kutuderesi Seyithan Köprüsü',0),
 ('eski-koy-celal-zeynep-koyu-bisiklet-parkuru','Bingöl','Bisiklet',12.7,180,'Zor','Path','Merkez Beşyol','Merkez Beşyol dönüş',0),
 ('elmali-koyu-soguk-cesme-bisiklet-parkuru','Bingöl','Bisiklet',27.67,300,'Orta','Path','Ilıcalar Beldesi','Ilıcalar Beldesi dönüş',0),
 ('aftor-celtiksuyu-murat-nehri-bisiklet-parkuru','Bingöl','Bisiklet',13.99,180,'Orta','Path','Aftor Kavşağı','Aftor Kavşağı dönüş',0),
 ('cinar-karacadag-lav-rotasi','Diyarbakır','Yürüyüş',11.3,240,'Kolay','KARACADAG LAV YOLU ROTASI IZ-F','Şimşek köyü yakınları','Dişlibozak köyü yakınları',0),
 ('cinar-zerzevan-kalesi-cemeres-rotasi','Diyarbakır','Yürüyüş',14.5,300,'Kolay','ÇEMERES ZERZEVAN ROTASI IZ-F','Çemereş Suyu','Zerzevan Kalesi',0),
]
TITLES=['Malatya merkez kültür yürüyüşü','Yeşilyurt kültür yürüyüşü','Girmana Kanyonu yürüyüşü','Tunceli – Ana Fatma bisiklet parkuru','Tunceli – Kutuderesi bisiklet parkuru','Eski Köy – Celal – Zeynep bisiklet turu','Elmalı Köyü – Soğuk Çeşme bisiklet turu','Aftor – Çeltiksuyu – Murat Nehri bisiklet turu','Çınar – Karacadağ Lav yürüyüşü','Çemereş – Zerzevan Kalesi yürüyüşü']

def build(root):
 records=[];photos=[]
 for spec,title in zip(SPECS,TITLES):
  slug,city,mode,km,mins,diff,track,start,end,index=spec
  meta=json.loads((root/(slug+'.json')).read_text());raw=(root/(slug+'.kml')).read_bytes()
  points=selected_points(raw,track);lengths=[meters(a,b) for a,b in zip(points,points[1:])];length=sum(lengths)
  assert 10<len(points)<=2000 and max(lengths)<700
  assert abs(length/1000/km-1)<.25,'Source distance mismatch'
  city_slug=meta['citySlug'];provider='kral' if city_slug=='diyarbakir' else 'firat'
  credit='Diyarbakır Kral Yolu' if provider=='kral' else 'Fırat’ı Keşfet'
  stops=[{'id':f'external_{provider}_{city_slug}_{slug}_{i}','name':name,'city':city,'latitude':p[1],'longitude':p[0],'imageUrl':'','category':'Gezi','description':'','bestTime':''} for i,(p,name) in enumerate([(points[0],start),(points[-1],end)])]
  note=f'Kaynak: {credit}. {meta["url"]}\nKaynak mesafesi: {km:g} km; harita izi: {length/1000:.2f} km. Kaynak süre tahmini: {mins} dakika. Kaynak zorluğu: {diff}. '
  if city_slug=='malatya':note+='Kaynak süre aralığının üst sınırı gösterilir. '
  if city_slug=='tunceli':note+='Kaynak tablosu gidiş-dönüş olarak etiketlenmiş olsa da KML iki farklı noktayı birleştirir. Haritada yalnızca bu tek yönlü iz gösterilir; dönüş eklenmemiştir. Süre kaynak tahminidir. '
  if city_slug=='diyarbakir':note+='KML içinden yalnızca yürüyüş izi alınmıştır; araçla ulaşım yolları dahil değildir. '
  if slug=='cinar-zerzevan-kalesi-cemeres-rotasi':note+='Başlangıç Çemereş/Yücebağ (Mardin–Mazıdağı) tarafındadır; bitiş Diyarbakır Çınar’daki Zerzevan Kalesi’dir. '
  note+='Duraklar kaynak parkurunun koordinatlarından alınmıştır. Parkur sahada yeniden doğrulanmamıştır; güncel yol ve erişim koşullarını kontrol edin.'
  track_url=urllib.parse.quote(urllib.parse.urljoin(meta['url'],meta['tracks'][0]).replace('http:','https:'),safe=':/?=&%')
  ident=f'tbt_ready_{provider}_{city_slug}_'+slug.replace('-','_')
  records.append({'id':ident,'title':title,'city':city,'transport':mode,'distanceKm':length/1000,'travelMinutes':mins,'durationHours':math.ceil(mins/60),'spotIds':[s['id'] for s in stops],'spotNames':[s['name'] for s in stops],'stopSnapshots':stops,'dayPlan':{'routeVersion':2,'signature':mode+'|null,null|false|'+';'.join(f'{s["latitude"]},{s["longitude"]}' for s in stops),'manual':False,'roundTrip':False,'geometry':[{'lat':lat,'lng':lon} for lon,lat in points],'legs':[{'meters':length,'seconds':mins*60}],'description':note,'difficulty':diff,'difficultyEstimated':True},'externalSource':{'name':credit,'url':meta['url'],'trackUrl':track_url,'resolvedTrackUrl':meta['resolved'],'sha256':hashlib.sha256(raw).hexdigest(),'retrievedOn':'2026-09-25','publishedDistanceKm':km,'publishedDurationMinutes':mins,'difficulty':diff,'returnTrackMirrored':False,'trackPointCount':len(points),'selectedTrackName':track,'fieldVerified':False}})
  photo=root/(slug+'-'+str(index)+'.image')
  photos.append({'id':ident,'sourceUrl':urllib.parse.quote(meta['images'][index],safe=':/?=&%'),'sourcePage':meta['url'],'credit':credit,'sha256':hashlib.sha256(photo.read_bytes()).hexdigest()})
  print(city,title,round(length/1000,2),'km',len(points),'points')
 return records,photos
if __name__=='__main__':
 records,photos=build(Path(sys.argv[1]));out=Path(__file__).resolve().parents[1]/'functions/scripts'
 (out/'nearby_expansion_routes.json').write_text(json.dumps(records,ensure_ascii=False,separators=(',',':'))+'\n')
 (out/'nearby_expansion_photos.json').write_text(json.dumps(photos,ensure_ascii=False,indent=2)+'\n')
