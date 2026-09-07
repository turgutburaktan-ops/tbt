"""Apply the shared Firestore reader to a staged copy of the existing website.

Does not download or deploy files. Fails closed if live source anchors drift.
Usage: python tool/patch_shared_spot_web.py /path/to/staged/public
"""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f'Expected one source anchor: {old[:80]}')
    return source.replace(old, new, 1)

def patch(source):
    if "from './spot-catalog.mjs'" in source:
        raise ValueError('Shared catalog already installed; review instead of patching twice.')
    source = "import { createSpotCatalog } from './spot-catalog.mjs';\n" + source
    source = once(source, 'getFirestore, collection,', 'getDocsFromServer, startAfter, documentId, getFirestore, collection,')
    if source.count('const spots = [\n') != 1:
        raise ValueError('Expected one static travel catalog.')
    start = source.index('const spots = [\n')
    end = source.index('\n];', start) + len('\n];')
    source = source[:start] + '''let spots = [];
let spotRenderGeneration = 0;
const sharedSpotCatalog = createSpotCatalog(async (cursor, pageSize) => {
  const constraints = [where('status','==','published'), where('coordinateVerified','==',true), orderBy(documentId()), limit(pageSize)];
  if (cursor) constraints.push(startAfter(cursor));
  const page = await getDocsFromServer(query(collection(db,'photo_spots'), ...constraints));
  return {docs:page.docs.map(d=>({id:d.id,data:d.data()})), cursor:page.docs.at(-1)};
});
async function loadSharedSpots() {
  spots = [...await sharedSpotCatalog.load()];
  const byId = new Map(spots.map(s=>[s.id,s]));
  selectedStops = selectedStops.map(s=>byId.get(s.id)).filter(Boolean);
}''' + source[end:]
    source = once(source, 'async function render(){', 'async function render(){\n  const spotGeneration = ++spotRenderGeneration;')
    source = once(source, "    if(route==='arama') await renderSearch();", """    if (['mekanlar','planla','arama'].includes(route)) {
      await loadSharedSpots();
      if (spotGeneration !== spotRenderGeneration) return;
    }
    if(route==='arama') await renderSearch();""")
    source = once(source, "}catch(e){console.error(e);app.innerHTML=errorCard(e.message||'Beklenmeyen hata');}", "}catch(e){if(spotGeneration!==spotRenderGeneration)return;console.error(e);app.innerHTML=errorCard(e.message||'Beklenmeyen hata');}")
    source = once(source, '  app.focus({preventScroll:true});', '  if(spotGeneration===spotRenderGeneration)app.focus({preventScroll:true});')
    start = source.index('const smartRouteFilter=')
    end = source.index('function venueQuery(', start)
    source = source[:start] + '''async function loadSmartRoute(city) {
  await loadSharedSpots();
  const area=await findVenueCity(city);
  const stops=spots.filter(s=>s.city.toLocaleLowerCase('tr')===area.name.toLocaleLowerCase('tr'))
    .sort((a,b)=>haversine(area.lat,area.lng,a.lat,a.lng)-haversine(area.lat,area.lng,b.lat,b.lng)).slice(0,6);
  if(!stops.length)throw new Error('Bu şehirde henüz doğrulanmış rota durağı yok.');
  return {area,stops};
}
''' + source[end:]
    start = source.index('  if(places.length)sections.push(')
    end = source.index('\n', start)
    block = source[start:end].replace('#/mekanlar/${x.id}', '#/mekanlar/${encodeURIComponent(x.id)}')
    for field in ['name','city','image']:
        block = block.replace('${x.'+field+'}', '${esc(x.'+field+')}')
    source = source[:start] + block + source[end:]
    # Previously the strings were literals. Escape all catalog-derived HTML
    # now that names/categories are remote; retain raw strings for logic/toasts.
    for begin, finish in [('async function renderPlaces(){','function venueTabs('),
                          ('function drawSpots(list){','function sortNearby('),
                          ('async function renderRoutes(){','function openMaps(')]:
        start, end = source.index(begin), source.index(finish)
        block = source[start:end]
        block = block.replace('#/mekanlar/${s.id}', '#/mekanlar/${encodeURIComponent(s.id)}')
        for field in ['id','name','city','category','best','image']:
            block = block.replace('${s.'+field+'}', '${esc(s.'+field+')}')
        block = block.replace('${c}</button>', '${esc(c)}</button>')
        block = block.replace('pageHead(s.name,', 'pageHead(esc(s.name),')
        block = block.replace('toast(`${esc(s.name)} ', 'toast(`${s.name} ')
        source = source[:start] + block + source[end:]
    source = once(source, "const grid=document.querySelector('#spotGrid');grid.innerHTML=list.map(", "const grid=document.querySelector('#spotGrid');grid.innerHTML=list.length?list.map(")
    source = once(source, "</div></div></article>`).join('');\n  grid.querySelectorAll('[data-stop]')", "</div></div></article>`).join(''):'<div class=\"empty\">Henüz yayınlanmış gezilecek yer bulunmuyor.</div>';\n  grid.querySelectorAll('[data-stop]')")
    return source

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('public_dir',type=Path)
    args=parser.parse_args()
    app=args.public_dir/'app.js'
    source=patch(app.read_text())
    sw=args.public_dir/'sw.js'
    old=sw.read_text()
    updated,count=re.subn(r"const CACHE='[^']+';", "const CACHE='tbt-shell-shared-spots-v1';",old)
    if count!=1: raise ValueError('Service worker cache anchor changed.')
    # All guards completed before any staged file is changed.
    app.write_text(source)
    sw.write_text(updated)
    (args.public_dir/'spot-catalog.mjs').write_text((ROOT/'web_shared/spot-catalog.mjs').read_text())

if __name__=='__main__': main()
