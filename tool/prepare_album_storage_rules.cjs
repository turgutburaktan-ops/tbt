const fs = require('node:fs');
const {GoogleAuth} = require('../functions/node_modules/google-auth-library');
(async () => {
 const client = await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const base = 'https://firebaserules.googleapis.com/v1/';
 async function read(release) {
  const r = (await client.request({url:base+'projects/en-iyi-cekim-noktasi/releases/'+release})).data;
  const set = (await client.request({url:base+r.rulesetName})).data;
  return set.source.files[0].content;
 }
 const storage = await read('firebase.storage/en-iyi-cekim-noktasi.firebasestorage.app');
 const firestore = await read('cloud.firestore');
 console.log('Live album rules: storage='+storage.includes('match /route_albums/')+', firestore='+firestore.includes('match /album/{mediaId}'));
 if (!firestore.includes('match /album/{mediaId}')) throw Error('Firestore album rules missing; review required');
 fs.writeFileSync('firestore.rules',firestore);
 if (storage.includes('match /route_albums/')) {
  fs.writeFileSync('storage.rules',storage);
  console.log('Album Storage rule already deployed; testing live policy');
 } else {
  const marker='match /b/{bucket}/o {';
  if (!storage.includes(marker)) throw Error('Unknown storage rules structure');
  const rule = `
    match /route_albums/{planId}/{uid}/{mediaId}/{fileName} {
      function participant() {
        return request.auth != null && firestore.get(/databases/(default)/documents/travel_plans/$(planId)).data.memberIds.hasAny([request.auth.uid]);
      }
      allow read: if participant();
      allow create: if participant() && request.auth.uid == uid && request.resource.size > 0 &&
        ((request.resource.contentType.matches('image/(jpeg|png|webp|heic|heif)') && request.resource.size <= 15 * 1024 * 1024) ||
         (request.resource.contentType.matches('video/(mp4|quicktime)') && request.resource.size <= 100 * 1024 * 1024)) &&
        (fileName == 'thumb.jpg' || fileName.matches('media[.](jpg|png|webp|heic|heif|mp4|mov)'));
      allow update: if false;
      allow delete: if participant() && request.auth.uid == uid;
    }
`;
  fs.writeFileSync('storage.rules',storage.replace(marker,marker+rule));
  console.log('Added missing member-only album path; existing Storage rules preserved');
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
