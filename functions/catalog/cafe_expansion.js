const {fold, meters, validPosition, cityName, venueRow} = require('./schema');
const phoneKey = s => String(s || '').replace(/\D/g, '').replace(/^90/, '').replace(/^0/, '');
const nameKey = s => fold(s).replace(/\b(cafe|coffee|kafe|kahve|shop)\b/g, '').replace(/\s+/g, ' ').trim() || fold(s);
function duplicate(a, b) {
  if (meters(a,b) > 120) return false;
  const an=nameKey(a.venueName || a.name), bn=nameKey(b.venueName || b.name);
  const ap=phoneKey(a.phone), bp=phoneKey(b.phone);
  return !!an && an === bn || ap.length >= 10 && ap === bp;
}
function indexRows(rows) {
  const cells = new Map();
  function cell(r){return [Math.floor(r.latitude*500),Math.floor(r.longitude*500)];}
  function add(r){
    if(!validPosition(r))return;
    const [a,o]=cell(r),k=`${a}:${o}`;
    if(!cells.has(k))cells.set(k,[]); cells.get(k).push(r);
  }
  rows.forEach(add);
  return {add,has(r){const [a,o]=cell(r);
    for(let da=-1;da<=1;da++)for(let d=-1;d<=1;d++)
      if((cells.get(`${a+da}:${o+d}`)||[]).some(x=>duplicate(r,x)))return true;
    return false;
  }};
}
function validate(row) {
  return row.source==='overture' && row.category==='cafe' && row.status==='published' &&
    Number.isFinite(row.sourceConfidence) && row.sourceConfidence >= .85 &&
    /^overture-[a-zA-Z0-9-]{8,100}$/.test(row.venueId) && !!cityName(row.city) &&
    !!venueRow(`cafe:${row.venueId}`,row,null);
}
module.exports={duplicate,indexRows,validate};
