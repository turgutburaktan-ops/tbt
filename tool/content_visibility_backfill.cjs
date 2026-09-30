const {backfillContent,owners}=require('../functions/content_visibility');
module.exports={backfillContent};
if (require.main === module) {
  const fromFunctions = require('node:module').createRequire(require.resolve('../functions/package.json'));
  const {initializeApp} = fromFunctions('firebase-admin/app');
  const {getFirestore} = fromFunctions('firebase-admin/firestore');
  initializeApp({projectId:'en-iyi-cekim-noktasi'});
  (async () => {
    const db = getFirestore(), apply = process.argv.includes('--apply'), counts = {}, byCollection = {};
    for (const collection of Object.keys(owners)) {
    byCollection[collection] = {};
    let cursor;
    while (true) {
      let q = db.collection(collection).orderBy('__name__').limit(100);
      if (cursor) q = q.startAfter(cursor);
      const page = await q.get();
      if (page.empty) break;
      for (const doc of page.docs) {
        const result = await backfillContent({db,ref:doc.ref,apply});
        counts[result] = (counts[result] || 0) + 1;
        byCollection[collection][result] = (byCollection[collection][result] || 0) + 1;
      }
      cursor = page.docs.at(-1);
    }
    }
    console.log('CONTENT_VISIBILITY_BACKFILL '+JSON.stringify({apply,counts,byCollection}));
    if (counts['invalid-owner']) process.exitCode = 1;
  })().catch(error => {console.error('Visibility backfill failed',error.code || error.message);process.exitCode=1;});
}
