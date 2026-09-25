'use strict';
const assert=require('node:assert/strict');
const cities={
 'Elazığ':{slug:'elazig',source:'firat',bounds:[38,40,38,41]},
 'Malatya':{slug:'malatya',source:'firat',bounds:[37.9,39.3,37,39.3]},
 'Tunceli':{slug:'tunceli',source:'firat',bounds:[38.7,39.7,38.6,40.5]},
 'Bingöl':{slug:'bingol',source:'firat',bounds:[38.4,40,39.6,41.4]},
 'Diyarbakır':{slug:'diyarbakir',source:'kral',bounds:[37.4,38.8,38.7,41.5]},
};
const sources={firat:{host:'firatikesfet.com',credit:'Fırat’ı Keşfet'},kral:{host:'diyarbakirkralyolu.com',credit:'Diyarbakır Kral Yolu'}};
function routeRegion(r){
 const region=cities[r.city];assert(region,'Unsupported province');
 assert.match(r.id,new RegExp(`^tbt_ready_${region.source}_${region.slug}_[a-z_]+$`));
 const u=new URL(r.externalSource.url);
 assert.equal(u.origin,`https://${sources[region.source].host}`);
 assert(u.pathname.startsWith(region.source==='firat'?`/tr/detail/${region.slug}/`:'/rota/'));
 return region;
}
function inside(lat,lng,b){return Number.isFinite(lat)&&Number.isFinite(lng)&&lat>b[0]&&lat<b[1]&&lng>b[2]&&lng<b[3];}
function validatePhoto(p,r){
 assert.equal(p.id,r.id);
 const u=new URL(p.sourceUrl),page=new URL(p.sourcePage);
 if(u.hostname==='www.kulturportali.gov.tr'){
  assert.equal(r.city,'Tunceli');
  assert.equal(page.href,'https://www.kulturportali.gov.tr/turkiye/tunceli/gezilecekyer/kirk-merdiven-selaleleri');
  assert.equal(p.credit,'Tunceli İl Kültür ve Turizm Müdürlüğü Arşivi / Kültür Portalı');
  assert(u.pathname.startsWith('/repoKulturPortali/'));
 }else{
  const source=sources[routeRegion(r).source];
  assert.equal(u.hostname,source.host);assert.equal(p.sourcePage,r.externalSource.url);assert.equal(p.credit,source.credit);
  assert(u.pathname.startsWith(source.host==='firatikesfet.com'?'/BackOffice/UploadImage/gallery/':'/wp-content/uploads/'));
 }
 assert.equal(u.protocol,'https:');assert(!u.username&&!u.password&&!u.port);
 assert.match(p.sha256,/^[a-f0-9]{64}$/);
}
const creditLine=p=>`\nKapak fotoğrafı: ${p.credit} (${p.credit==='Fırat’ı Keşfet'||p.credit==='Diyarbakır Kral Yolu'?'rota kaynak sayfası':p.sourcePage}).`;
module.exports={routeRegion,inside,validatePhoto,creditLine};
