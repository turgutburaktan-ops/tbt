"""Build reviewed neighboring-province routes from source KML/GPX and original photos.

Input directory contains <slug>.json (page metadata), <slug>.kml/.gpx,
photo-jobs.json (original image URLs), and <photo-key>.image (original bytes).
Only explicitly selected walking/bicycle tracks are imported; car approaches
and disconnected segments must never be concatenated.
"""
import json, math, hashlib, sys, urllib.parse
from pathlib import Path
import xml.etree.ElementTree as E
from prepare_elazig_external_routes import meters

SPECS=[
 ('malatya','Malatya','arslantepe-yuruyus-parkuru','Arslantepe Höyüğü yürüyüşü','Yürüyüş',1,30,'Kolay','Aslantepe Rota','Arslantepe parkur başlangıcı','Arslantepe parkur bitişi','arslantepe-yuruyus-parkuru-0'),
 ('malatya','Malatya','battalgazi-yuruyus-parkuru','Battalgazi kültür yürüyüşü','Yürüyüş',5,240,'Kolay','Battalgazi Kültür Rotası','Battalgazi parkur başlangıcı','Battalgazi parkur bitişi','battalgazi-yuruyus-parkuru-0'),
 ('tunceli','Tunceli','ovacik-kirk-merdiven-selaleleri-rotasi','Ovacık – Kırk Merdiven Şelaleleri yürüyüşü','Yürüyüş',14.5,300,'Kolay','Kırk Merdiven Şelalesi Rotası','Kırk Merdiven yürüyüş başlangıcı','Kırk Merdiven yürüyüş bitişi','kirk-photo'),
 ('bingol','Bingöl','asagi-carsi-bisiklet-parkuru','Bingöl – Aşağı Çarşı bisiklet turu','Bisiklet',6.02,120,'Orta','Path','Öğretmenevi önü','Öğretmenevi önü dönüş','asagi-carsi-bisiklet-parkuru-0'),
 ('diyarbakir','Diyarbakır','cermik-merkez-kultur-gezi-rotasi','Çermik merkez kültür yürüyüşü','Yürüyüş',4.2,60,'Kolay','10-ÇERMİK MERKEZ KÜLTÜR GEZİ ROTASI','Çermik parkur başlangıcı','Çermik parkur bitişi','cermik-photo'),
]

def selected_points(raw,name):
 tree=E.fromstring(raw)
 selected=[pm for pm in tree.findall('.//{*}Placemark') if pm.findtext('{*}name')==name]
 assert len(selected)==1,('Ambiguous/missing track',name)
 lines=selected[0].findall('.//{*}LineString/{*}coordinates')
 assert len(lines)==1,'Disconnected tracks need independent review'
 points=[]
 for item in lines[0].text.split():
  p=tuple(map(float,item.split(',')[:2]))
  if not points or points[-1]!=p:points.append(p)
 return points

def build(root):
 records=[];photos=[];photo_urls=json.loads((root/'photo-jobs.json').read_text())
 for city_slug,city,slug,title,mode,km,mins,diff,track,start,end,photo_key in SPECS:
  meta=json.loads((root/(slug+'.json')).read_text())
  provider='kral' if city_slug=='diyarbakir' else 'firat'
  credit='Diyarbakır Kral Yolu' if provider=='kral' else 'Fırat’ı Keşfet'
  raw=(root/(slug+('.gpx' if provider=='kral' else '.kml'))).read_bytes()
  points=selected_points(raw,track)
  assert 10<len(points)<=2000
  lengths=[meters(a,b) for a,b in zip(points,points[1:])];length=sum(lengths)
  assert max(lengths)<700 and km*.75<length/1000<km*1.25
  stops=[{'id':f'external_{provider}_{city_slug}_{slug}_{i}','name':name,'city':city,'latitude':p[1],'longitude':p[0],'imageUrl':'','category':'Gezi','description':'','bestTime':''} for i,(p,name) in enumerate([(points[0],start),(points[-1],end)])]
  note=f'Kaynak: {credit}. {meta["url"]}\nKaynak mesafesi: {km:g} km; harita izi: {length/1000:.2f} km. Kaynak süre tahmini: {mins} dakika. Kaynak zorluğu: {diff}. '
  if city_slug=='tunceli':note+='KML içinden yalnızca yürüyüş izi alınmıştır; araçla ulaşım yolu dahil değildir. '
  if slug.startswith('battalgazi'):note+='Kaynakta süre 3–4 saat olarak verilir; kartta üst sınır gösterilir. '
  note+='Duraklar kaynak parkurunun koordinatlarından alınmıştır. Parkur sahada yeniden doğrulanmamıştır; güncel yol ve erişim koşullarını kontrol edin.'
  track_url=urllib.parse.quote(urllib.parse.urljoin(meta['url'],meta['tracks'][0]).replace('http:','https:'),safe=':/?=&%')
  day={'routeVersion':2,'signature':mode+'|null,null|false|'+';'.join(f'{s["latitude"]},{s["longitude"]}' for s in stops),'manual':False,'roundTrip':False,'geometry':[{'lat':lat,'lng':lon} for lon,lat in points],'legs':[{'meters':length,'seconds':mins*60}],'description':note,'difficulty':diff,'difficultyEstimated':True}
  ident=f'tbt_ready_{provider}_{city_slug}_'+slug.replace('-','_')
  records.append({'id':ident,'title':title,'city':city,'transport':mode,'distanceKm':length/1000,'travelMinutes':mins,'durationHours':math.ceil(mins/60),'spotIds':[s['id'] for s in stops],'spotNames':[s['name'] for s in stops],'stopSnapshots':stops,'dayPlan':day,'externalSource':{'name':credit,'url':meta['url'],'trackUrl':track_url,'resolvedTrackUrl':meta.get('resolved',track_url),'sha256':hashlib.sha256(raw).hexdigest(),'retrievedOn':'2026-09-25','publishedDistanceKm':km,'publishedDurationMinutes':mins,'difficulty':diff,'returnTrackMirrored':False,'trackPointCount':len(points),'selectedTrackName':track,'fieldVerified':False}})
  photo_page=meta['url']
  if photo_key=='kirk-photo':
   credit='Tunceli İl Kültür ve Turizm Müdürlüğü Arşivi / Kültür Portalı'
   photo_page='https://www.kulturportali.gov.tr/turkiye/tunceli/gezilecekyer/kirk-merdiven-selaleleri'
  photos.append({'id':ident,'sourceUrl':urllib.parse.quote(photo_urls[photo_key],safe=':/?=&%'),'sourcePage':photo_page,'credit':credit,'sha256':hashlib.sha256((root/(photo_key+'.image')).read_bytes()).hexdigest()})
  print(city,title,round(length/1000,2),'km',len(points),'points')
 return records,photos
if __name__=='__main__':
 records,photos=build(Path(sys.argv[1]));out=Path(__file__).resolve().parents[1]/'functions/scripts'
 (out/'nearby_ready_routes.json').write_text(json.dumps(records,ensure_ascii=False,separators=(',',':'))+'\n')
 (out/'nearby_route_photos.json').write_text(json.dumps(photos,ensure_ascii=False,indent=2)+'\n')
