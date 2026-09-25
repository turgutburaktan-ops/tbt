"""Convert downloaded publisher KMLs into standalone route snapshots.

Usage: python3 tool/prepare_elazig_external_routes.py SOURCE_DIRECTORY
Only geographic facts and track coordinates are imported; no photos or copied prose.
"""
import hashlib
import json
import math
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

NS = {'k': 'http://www.opengis.net/kml/2.2'}
DEFINITIONS = [
    ('harput-yuruyus-parkuru', 'Harput yürüyüş parkuru', 'Yürüyüş', 5, 120, 'Kolay',
     'Harput başlangıç noktası', 'Harput bitiş noktası',
     'https://firatikesfet.com/BackOffice/Uploads/ckfinder/kml/0831_8n2mhv6r8_Harput.kml'),
    ('iv-murat-hani-yuruyus-parkuru', 'Alacakaya – IV. Murat Hanı yürüyüşü', 'Yürüyüş', 14.4, 300, 'Orta',
     'Alacakaya başlangıç noktası', 'Alacakaya dönüş noktası',
     'https://firatikesfet.com/BackOffice/Uploads/ckfinder/kml/0639_wd5yeaf7e_Alacakaya-4.-Murat-Han---Alacakaya.kml'),
    ('keban-bisiklet-parkuru', 'Keban bisiklet parkuru', 'Bisiklet', 7, 120, 'Kolay',
     'Keban başlangıç noktası', 'Keban bitiş noktası',
     'https://www.firatikesfet.com/BackOffice/Uploads/ckfinder/kml/Keban.zip'),
    ('cip-mesire-yeri-bisiklet-parkuru', 'Elazığ – Cip Mesire Yeri bisiklet turu', 'Bisiklet', 29.4, 360, 'Orta',
     'Elazığ Öğretmenevi başlangıç', 'Elazığ Öğretmenevi dönüş',
     'https://firatikesfet.com/BackOffice/Uploads/ckfinder/kml/1912_7xnzfiw7s_Cip-Mesire-Yeri-Bisiklet-Rotas--.kml'),
]

def meters(a, b):
    lon1, lat1, lon2, lat2 = map(math.radians, [a[0], a[1], b[0], b[1]])
    h = math.sin((lat2-lat1)/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin((lon2-lon1)/2)**2
    return 6371000 * 2 * math.asin(math.sqrt(min(1, h)))

def build(directory):
    records = []
    for slug, title, mode, published_km, minutes, difficulty, start, end, track_url in DEFINITIONS:
        path = directory / ('keban-map.kml' if slug.startswith('keban') else slug+'.kml')
        raw = path.read_bytes()
        root = ET.fromstring(raw)
        segments = [[tuple(map(float, p.split(',')[:2])) for p in c.text.split()]
                    for c in root.findall('.//k:LineString/k:coordinates', NS)]
        if not segments or any(len(s) < 2 for s in segments):
            raise ValueError('Missing track: '+slug)
        points = []
        for segment in segments:
            if points and meters(points[-1], segment[0]) > 30:
                raise ValueError('Disconnected source track: '+slug)
            for point in segment:
                if not (38 < point[0] < 41 and 38 < point[1] < 40):
                    raise ValueError('Out-of-region point: '+slug)
                if not points or points[-1] != point:
                    points.append(point)
        outbound_count = len(points)
        mirrored = slug.startswith('cip-')
        if mirrored:
            points += list(reversed(points[:-1]))
        if len(points) > 2000:
            raise ValueError('Track exceeds existing mobile geometry limit')
        length = sum(meters(a,b) for a,b in zip(points, points[1:]))
        if not published_km * 0.75 < length/1000 < published_km * 1.25:
            raise ValueError('Unexpected source distance: '+slug)
        if max(meters(a,b) for a,b in zip(points, points[1:])) > 700:
            raise ValueError('Unexpected track gap: '+slug)
        stop_points = [(0, start)]
        if mirrored:
            stop_points.append((outbound_count-1, 'Cip Mesire Yeri'))
        stop_points.append((len(points)-1, end))
        stops = [{'id': f'external_firat_{slug}_{i}', 'name': name, 'city': 'Elazığ',
                  'latitude': points[index][1], 'longitude': points[index][0],
                  'imageUrl': '', 'category': 'Gezi', 'description': '', 'bestTime': ''}
                 for i,(index,name) in enumerate(stop_points)]
        source_url = 'https://firatikesfet.com/tr/detail/elazig/'+slug
        note = (f'Kaynak: Fırat’ı Keşfet. {source_url}\n'
                f'Kaynakta belirtilen mesafe: {published_km:g} km; harita izi: {length/1000:.2f} km. '
                f'Kaynak zorluğu: {difficulty}. Kaynak süre tahmini: {minutes} dakika. '
                'Başlangıç ve bitiş koordinatları kaynak parkurundan alınmıştır; '
                'Gezilecek Yerler kataloğuna kayıt gerekmez. ')
        if mirrored:
            note += 'KML yalnızca gidişi içerir; gidiş-dönüş turu aynı izin ters yönde eklenmesiyle hazırlanmıştır. '
        note += 'Kaynak parkuru sahada yeniden doğrulanmamıştır; güncel yol ve erişim koşullarını kontrol edin.'
        signature = mode+'|null,null|false|'+';'.join(f"{s['latitude']},{s['longitude']}" for s in stops)
        leg_lengths = [sum(meters(a,b) for a,b in zip(points[x:y],points[x+1:y+1]))
                       for (x,_),(y,_) in zip(stop_points,stop_points[1:])]
        day = {'routeVersion':2,'signature':signature,'manual':False,'roundTrip':False,
               'geometry':[{'lat':lat,'lng':lon} for lon,lat in points],
               'legs':[{'meters':d,'seconds':minutes*60*d/length} for d in leg_lengths],
               'description':note,'difficulty':difficulty,'difficultyEstimated':True}
        records.append({'id':'tbt_ready_firat_elazig_'+slug.replace('-','_'), 'title':title,
                        'city':'Elazığ','transport':mode,'distanceKm':length/1000,
                        'travelMinutes':minutes,'durationHours':math.ceil(minutes/60),
                        'spotIds':[s['id'] for s in stops],'spotNames':[s['name'] for s in stops],
                        'stopSnapshots':stops,'dayPlan':day,
                        'externalSource':{'name':'Fırat’ı Keşfet','url':source_url,'trackUrl':track_url,
                         'resolvedTrackUrl': ('https://www.google.com/maps/d/u/2/kml?forcekml=1&mid=1gk_EY-J5RT4xi_lUorGblAZUmcpFtMCJ' if slug.startswith('keban') else track_url),
                         'sha256':hashlib.sha256(raw).hexdigest(),'retrievedOn':'2026-09-25',
                         'publishedDistanceKm':published_km,'publishedDurationMinutes':minutes,
                         'difficulty':difficulty,'returnTrackMirrored':mirrored,
                         'trackPointCount':outbound_count,'fieldVerified':False}})
    return records

if __name__ == '__main__':
    records = build(Path(sys.argv[1]))
    output = Path(__file__).resolve().parents[1]/'functions/scripts/elazig_external_routes.json'
    output.write_text(json.dumps(records, ensure_ascii=False, separators=(',',':'))+'\n')
    for r in records:
        print(r['title'], round(r['distanceKm'],2), len(r['dayPlan']['geometry']), 'points')
