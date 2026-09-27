"""Build the reviewed second batch from downloaded source pages and KMLs."""
import json, math, hashlib, sys, urllib.parse
from pathlib import Path
import xml.etree.ElementTree as E
from prepare_elazig_external_routes import meters, NS

SPECS=[
 ('buzluk-magarasi-bisiklet-parkuru','Harput – Buzluk Mağarası bisiklet turu','Bisiklet',12,120,'Kolay','Harput','Buzluk Mağarası',True,7),
 ('elazig-merkez-yuruyus-parkuru','Elazığ merkez kültür yürüyüşü','Yürüyüş',10,300,'Kolay','Elazığ Öğretmenevi','Elazığ Öğretmenevi',False,11),
 ('hazarbaba-yuruyus-parkuru','Hazarbaba zirve yürüyüşü','Yürüyüş',10.8,300,'Zor','Hazarbaba Kayak Merkezi','Hazarbaba Kayak Merkezi',False,12),
 ('suluklu-gol-yuruyus-parkuru','Ağın – Sülüklü Göl yürüyüşü','Yürüyüş',7.17,240,'Orta','Balkayası köyü','Balkayası köyü',False,18),
 ('kurk-dedeyolu-yuruyus-parkuru','Kürk – Dedeyolu yürüyüş parkuru','Yürüyüş',21.1,480,'Zor','Dedeyolu köyü','Eskibağlar Butik Otel',False,7),
 ('sarili-bisiklet-parkuru','Elazığ – Sarılı bisiklet turu','Bisiklet',46.8,300,'Orta','Elazığ parkur başlangıcı','Sarılı köyü',True,4),
]

def build(root):
 records=[]; photos=[]
 for slug,title,mode,km,mins,diff,start,end,mirror,photo_index in SPECS:
  meta=json.loads((root/(slug+'.json')).read_text());raw=(root/(slug+'.kml')).read_bytes()
  tree=E.fromstring(raw);points=[]
  for c in tree.findall('.//k:LineString/k:coordinates',NS):
   segment=[tuple(map(float,p.split(',')[:2])) for p in c.text.split()]
   assert len(segment)>1
   if points:assert meters(points[-1],segment[0])<30
   for p in segment:
    assert 38<p[0]<41 and 38<p[1]<40
    if not points or p!=points[-1]:points.append(p)
  outbound=len(points)
  stops_index=[(0,start)]
  if mirror:
   stops_index.append((len(points)-1,end));points+=list(reversed(points[:-1]));end=start+' dönüş'
  stops_index.append((len(points)-1,end))
  assert 10<len(points)<=2000
  lengths=[meters(a,b) for a,b in zip(points,points[1:])];length=sum(lengths)
  assert max(lengths)<700 and km*.75<length/1000<km*1.25
  stops=[{'id':f'external_firat_{slug}_{i}','name':name,'city':'Elazığ','latitude':points[n][1],'longitude':points[n][0],'imageUrl':'','category':'Gezi','description':'','bestTime':''} for i,(n,name) in enumerate(stops_index)]
  note=f'Kaynak: Fırat’ı Keşfet. {meta["url"]}\nKaynak mesafesi: {km:g} km; harita izi: {length/1000:.2f} km. Kaynak süre tahmini: {mins} dakika. Kaynak zorluğu: {diff}. '
  if mirror:note+='KML yalnızca gidişi içerir; dönüş aynı izin ters yönde eklenmesiyle hazırlanmıştır. '
  note+='Duraklar kaynak parkurunun koordinatlarından alınmıştır. Parkur sahada yeniden doğrulanmamıştır; güncel yol ve erişim koşullarını kontrol edin.'
  day={'routeVersion':2,'signature':mode+'|null,null|false|'+';'.join(f'{s["latitude"]},{s["longitude"]}' for s in stops),'manual':False,'roundTrip':False,'geometry':[{'lat':lat,'lng':lon} for lon,lat in points],
   'legs':[{'meters':sum(lengths[x:y]),'seconds':mins*60*sum(lengths[x:y])/length} for (x,_),(y,_) in zip(stops_index,stops_index[1:])],
   'description':note,'difficulty':diff,'difficultyEstimated':True}
  ident='tbt_ready_firat_elazig_'+slug.replace('-','_')
  records.append({'id':ident,'title':title,'city':'Elazığ','transport':mode,'distanceKm':length/1000,'travelMinutes':mins,'durationHours':math.ceil(mins/60),'spotIds':[s['id'] for s in stops],'spotNames':[s['name'] for s in stops],'stopSnapshots':stops,'dayPlan':day,
   'externalSource':{'name':'Fırat’ı Keşfet','url':meta['url'],'trackUrl':urllib.parse.quote(urllib.parse.urljoin('https://firatikesfet.com',meta['tracks'][0]).replace('http:','https:'),safe=':/?=&%'),'resolvedTrackUrl':meta['resolved'],'sha256':hashlib.sha256(raw).hexdigest(),'retrievedOn':'2026-09-25','publishedDistanceKm':km,'publishedDurationMinutes':mins,'difficulty':diff,'returnTrackMirrored':mirror,'trackPointCount':outbound,'fieldVerified':False}})
  photo=root/(slug+'-'+str(photo_index)+'.jpg')
  photos.append({'id':ident,'sourceUrl':meta['images'][photo_index],'sourcePage':meta['url'],'credit':'Fırat’ı Keşfet','sha256':hashlib.sha256(photo.read_bytes()).hexdigest()})
  print(title,round(length/1000,2),'km',len(points),'points')
 return records,photos
if __name__=='__main__':
 records,photos=build(Path(sys.argv[1]));out=Path(__file__).resolve().parents[1]/'functions/scripts'
 (out/'elazig_expansion_routes.json').write_text(json.dumps(records,ensure_ascii=False,separators=(',',':'))+'\n')
 (out/'elazig_expansion_photos.json').write_text(json.dumps(photos,ensure_ascii=False,indent=2)+'\n')
