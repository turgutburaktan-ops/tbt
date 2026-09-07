import {readFile} from 'node:fs/promises';
import test from 'node:test';
import assert from 'node:assert/strict';
import {decodeSpot,filterSpots,createSpotCatalog,previewUrl} from './spot-catalog.mjs';

const cases=JSON.parse(await readFile(new URL('../test/fixtures/shared_spots.json',import.meta.url),'utf8'));
const base=cases[0].data;
const doc=i=>({id:String(i).padStart(5,'0'),data:{...base,name:`Yer ${i}`,latitude:35.5+(i%100)*0.01,longitude:26+Math.floor(i/100)*0.01}});

test('same publication fixtures as mobile; document ID wins',()=>{
  for(const fixture of cases){
    const spot=decodeSpot(fixture.id,fixture.data);
    assert.equal(!!spot,fixture.accepted,fixture.id);
    if(spot)assert.equal(spot.id,fixture.id);
  }
});
test('global names and 18m neighbors across grid edges use stable IDs',()=>{
  const a=decodeSpot('a',{...base,latitude:38.00099});
  const near=decodeSpot('b',{...base,name:'Başka ad',latitude:38.00101});
  const name=decodeSpot('c',{...base,name:'PERTEK KALESİ',latitude:39});
  const far=decodeSpot('d',{...base,name:'Uzak yer',latitude:39.1});
  assert.deepEqual(filterSpots([far,name,near,a]).map(s=>s.id),['a','d']);
});
test('reads all 2501 records, shares inflight work and honors the cache',async()=>{
  const docs=Array.from({length:2501},(_,i)=>doc(i));let calls=0;
  const catalog=createSpotCatalog(async(cursor,size)=>{
    calls++;const start=cursor===null?0:Number(cursor)+1;
    const page=docs.slice(start,start+size);
    return {docs:page,cursor:page.at(-1)?.id};
  });
  const [a,b]=await Promise.all([catalog.load(),catalog.load()]);
  assert.equal(a.length,2501);assert.equal(a,b);assert.equal(calls,6);
  await catalog.load();assert.equal(calls,6);
});
test('empty server response replaces the old list after unpublishing',async()=>{
  let docs=[doc(0)];
  const catalog=createSpotCatalog(async()=>({docs}));
  assert.equal((await catalog.load()).length,1);
  docs=[];assert.deepEqual(await catalog.load({refresh:true}),[]);
});
test('a failed later page never replaces the complete cached catalog',async()=>{
  let fail=false;
  const catalog=createSpotCatalog(async(cursor,size)=>{
    if(!fail)return {docs:[doc(2500)]};
    if(cursor!==null)throw new Error('network');
    return {docs:Array.from({length:size},(_,i)=>doc(i)),cursor:'499'};
  });
  const complete=await catalog.load();fail=true;
  assert.equal(await catalog.load({refresh:true}),complete);
});
test('first-load error is visible; retry remains possible',async()=>{
  let fail=true;
  const catalog=createSpotCatalog(async()=>{
    if(fail)throw new Error('network');return {docs:[doc(1)]};
  });
  await assert.rejects(catalog.load(),/network/);
  fail=false;assert.equal((await catalog.load()).length,1);
});
test('a hanging request times out without caching an empty result',async()=>{
  const catalog=createSpotCatalog(()=>new Promise(()=>{}),{timeout:5});
  await assert.rejects(catalog.load(),/Gezilecek yerler/);
});
test('Commons originals become remote 500px previews',()=>{
  assert.match(previewUrl('https://commons.wikimedia.org/wiki/Special:FilePath/Test.jpg?width=1920'),/width=500/);
  assert.equal(previewUrl('https://upload.wikimedia.org/wikipedia/commons/a/ab/Test.jpg'),'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Test.jpg/500px-Test.jpg');
});
