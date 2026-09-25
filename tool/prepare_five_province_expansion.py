"""Reviewed batch: Elazig and four neighboring provinces; original source covers."""
import json,math,hashlib,sys,urllib.parse
from pathlib import Path
import xml.etree.ElementTree as E

def selected_points(raw,name):
 tree=E.fromstring(raw)
 selected=[pm for pm in tree.findall(".//{*}Placemark") if pm.findtext("{*}name")==name and pm.find(".//{*}LineString") is not None]
 assert len(selected)==1,("Ambiguous/missing line track",name)
 lines=selected[0].findall(".//{*}LineString/{*}coordinates");assert len(lines)==1
 points=[]
 for item in lines[0].text.split():
  p=tuple(map(float,item.split(",")[:2]))
  if not points or points[-1]!=p:points.append(p)
 return points
from prepare_elazig_external_routes import meters

# slug, city, mode, published km, minutes, difficulty, track name, start, end, photo, mirror
SPECS=[
 ('sivrice-eskibaglar-yuruyus-parkuru','Elazığ','Yürüyüş',20.6,360,'Orta','Path','Sivrice ilçe merkezi','Sivrice ilçe merkezi dönüş',0,False),
 ('cip-mesire-yeri-yuruyus-parkuru','Elazığ','Yürüyüş',3.5,120,'Kolay','Path','Cip Mesire Yeri başlangıcı','Cip Mesire Yeri bitişi',0,False),
 ('kockale-bisiklet-parkuru','Elazığ','Bisiklet',64,360,'Orta','1. parkur','Elazığ Öğretmenevi','Koçkale',0,True),
 ('icme-bisiklet-parkuru','Elazığ','Bisiklet',84,420,'Zor','1. parkur','Elazığ Öğretmenevi','Aşağı İçme',0,True),
 ('onar-koyu-yuruyus-parkuru','Malatya','Yürüyüş',1.5,120,'Kolay','Onar Köyü','Onar köyü merkezi','Onar köyü merkezi dönüş',0,False),
 ('levent-vadisi-fosil-magaralari-yuruyus-parkuru','Malatya','Yürüyüş',4,300,'Orta','Seyir Terası Fosil mağalar Rotası','Levent Vadisi Seyir Terası','Fosil mağaraları parkuru bitişi',0,False),
 ('cemisgezek-ulukale-rotasi','Tunceli','Bisiklet',32,300,'Zor','Çemişgezek - Ulukale Köyü Bisiklet Rotası','Çemişgezek ilçe merkezi','Ulukale köyü',0,False),
 ('merkez-ovacik-bisiklet-rotasi','Tunceli','Bisiklet',60,420,'Zor','Tunceli Merkez - Ovacık Bisiklet Rotası','Tunceli Müzesi','Ovacık ilçe merkezi',0,False),
 ('solhan-aksakal-koyu-yuzen-adalar-bisiklet-parkuru','Bingöl','Bisiklet',27.16,240,'Zor','Path','Solhan Belediyesi önü','Solhan Belediyesi önü dönüş',0,False),
 ('capakcur-vadisi-bisiklet-parkuru','Bingöl','Bisiklet',11.07,120,'Orta','Path','Kalium AVM karşısı','Üniversite Kavşağı',0,False),
 ('yenisehir-sancar-pirares-devegecidi-rotasi','Diyarbakır','Yürüyüş',15.6,300,'Kolay','YENISEHIR, SANCAR PRIRES-DEVEGECIDI ROTASI IZ-F','Sancar – Pirareş Köprüsü','Devegeçidi Köprüsü',1,False),
 ('yenisehir-tilham-diyarbakir-merkez-rotasi','Diyarbakır','Yürüyüş',44.7,720,'Kolay','YENISEHIR, TILHAM-DIYARBAKIR MRK ON GOZLU ROTASI-IZ-F','Tılham Piknik Alanı','On Gözlü Köprü',0,False),
]
TITLES=['Sivrice – Kürk – Eskibağlar yürüyüşü','Cip Mesire Yeri yürüyüşü','Elazığ – Koçkale bisiklet turu','Elazığ – İçme bisiklet turu','Onar Köyü kültür yürüyüşü','Levent Vadisi – Fosil Mağaraları yürüyüşü','Çemişgezek – Ulukale bisiklet parkuru','Tunceli – Ovacık bisiklet parkuru','Solhan – Yüzen Adalar bisiklet turu','Çapakçur Vadisi bisiklet parkuru','Sancar – Pirareş – Devegeçidi yürüyüşü','Tılham – Diyarbakır – On Gözlü Köprü yürüyüşü']

def simplify(points,tolerance=2):
 """RDP in local metric coordinates; endpoints preserved, tolerance in meters."""
 scale=math.cos(math.radians(sum(p[1] for p in points)/len(points)))
 xy=[(math.radians(p[0])*6371000*scale,math.radians(p[1])*6371000) for p in points]
 keep={0,len(points)-1};stack=[(0,len(points)-1)]
 while stack:
  lo,hi=stack.pop();a,b=xy[lo],xy[hi];dx,dy=b[0]-a[0],b[1]-a[1];den=dx*dx+dy*dy
  far,index=0,None
  for i in range(lo+1,hi):
   p=xy[i];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/den)) if den else 0
   d=math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)
   if d>far:far,index=d,i
  if far<=tolerance and math.hypot(dx,dy)>650 and hi-lo>1:
   far,index=tolerance+1,(lo+hi)//2
  if far>tolerance:
   keep.add(index);stack.extend([(lo,index),(index,hi)])
 return [points[i] for i in sorted(keep)]

def build(root):
 records=[];photos=[]
 for spec,title in zip(SPECS,TITLES):
  slug,city,mode,km,mins,diff,track,start,end,index,mirror=spec
  meta=json.loads((root/(slug+'.json')).read_text());raw=(root/(slug+'.kml')).read_bytes()
  points=selected_points(raw,track);source_count=len(points);original_length=sum(meters(a,b) for a,b in zip(points,points[1:]));tolerance=0
  if len(points)>2000:
   tolerance=2;points=simplify(points,tolerance)
   assert abs(sum(meters(a,b) for a,b in zip(points,points[1:]))/original_length-1)<.01
  stops_index=[(0,start)]
  if mirror:
   stops_index.append((len(points)-1,end));points+=list(reversed(points[:-1]));end=start+' dönüş'
  stops_index.append((len(points)-1,end))
  lengths=[meters(a,b) for a,b in zip(points,points[1:])];length=sum(lengths)
  assert 10<len(points)<=2000 and max(lengths)<700,(slug,len(points),max(lengths))
  assert abs(length/1000/km-1)<.25,(slug,length/1000,km)
  city_slug=meta['citySlug'];provider='kral' if city_slug=='diyarbakir' else 'firat';credit='Diyarbakır Kral Yolu' if provider=='kral' else 'Fırat’ı Keşfet'
  stops=[{'id':f'external_{provider}_{city_slug}_{slug}_{i}','name':name,'city':city,'latitude':points[n][1],'longitude':points[n][0],'imageUrl':'','category':'Gezi','description':'','bestTime':''} for i,(n,name) in enumerate(stops_index)]
  note=f'Kaynak: {credit}. {meta["url"]}\nKaynak mesafesi: {km:g} km; harita izi: {length/1000:.2f} km. Kaynak süre tahmini: {mins} dakika. Kaynak zorluğu: {diff}. '
  if mirror:note+='KML yalnızca gidişi içerir; dönüş aynı izin ters yönde eklenmesiyle hazırlanmıştır. '
  if city_slug=='malatya':note+='Kaynak süre aralığının üst sınırı gösterilir. '
  if city_slug=='tunceli':note+='Kaynak tablosu gidiş-dönüş olarak etiketlenmiş olsa da KML iki farklı noktayı birleştirir. Haritada yalnızca bu tek yönlü iz gösterilir; dönüş eklenmemiştir. Süre kaynak tahminidir. '
  if city_slug=='diyarbakir':note+='KML içinden yalnızca yürüyüş izi alınmıştır; araçla ulaşım yolları dahil değildir. '
  if tolerance:note+=f'Harita izi {tolerance} metre toleransla sadeleştirilmiştir; başlangıç ve bitiş korunmuştur. '
  note+='Duraklar kaynak parkurunun koordinatlarından alınmıştır. Parkur sahada yeniden doğrulanmamıştır; güncel yol ve erişim koşullarını kontrol edin.'
  track_url=urllib.parse.quote(urllib.parse.urljoin(meta['url'],meta['tracks'][0]).replace('http:','https:'),safe=':/?=&%');ident=f'tbt_ready_{provider}_{city_slug}_'+slug.replace('-','_')
  records.append({'id':ident,'title':title,'city':city,'transport':mode,'distanceKm':length/1000,'travelMinutes':mins,'durationHours':math.ceil(mins/60),'spotIds':[s['id'] for s in stops],'spotNames':[s['name'] for s in stops],'stopSnapshots':stops,'dayPlan':{'routeVersion':2,'signature':mode+'|null,null|false|'+';'.join(f'{s["latitude"]},{s["longitude"]}' for s in stops),'manual':False,'roundTrip':False,'geometry':[{'lat':lat,'lng':lon} for lon,lat in points],'legs':[{'meters':sum(lengths[x:y]),'seconds':mins*60*sum(lengths[x:y])/length} for (x,_),(y,_) in zip(stops_index,stops_index[1:])],'description':note,'difficulty':diff,'difficultyEstimated':True},'externalSource':{'name':credit,'url':meta['url'],'trackUrl':track_url,'resolvedTrackUrl':meta['resolved'],'sha256':hashlib.sha256(raw).hexdigest(),'retrievedOn':'2026-09-25','publishedDistanceKm':km,'publishedDurationMinutes':mins,'difficulty':diff,'returnTrackMirrored':mirror,'trackPointCount':source_count,'selectedTrackName':track,'fieldVerified':False,'simplificationToleranceMeters':tolerance,'originalSelectedTrackMeters':original_length}})
  photo=root/(slug+'-'+str(index)+'.image');photos.append({'id':ident,'sourceUrl':urllib.parse.quote(meta['images'][index],safe=':/?=&%'),'sourcePage':meta['url'],'credit':credit,'sha256':hashlib.sha256(photo.read_bytes()).hexdigest()})
  print(city,title,round(length/1000,2),'km',len(points),'points')
 return records,photos
if __name__=='__main__':
 records,photos=build(Path(sys.argv[1]));out=Path(__file__).resolve().parents[1]/'functions/scripts'
 (out/'five_province_routes.json').write_text(json.dumps(records,ensure_ascii=False,separators=(',',':'))+'\n')
 (out/'five_province_photos.json').write_text(json.dumps(photos,ensure_ascii=False,indent=2)+'\n')
