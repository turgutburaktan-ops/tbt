const {_sealChatFile, _privatePath} = require('../functions/chat_media_security');
const BUCKET = 'en-iyi-cekim-noktasi.firebasestorage.app';
async function denied(url) {
  const response = await fetch(url, {headers: {Range: 'bytes=0-0', 'Cache-Control': 'no-cache'}});
  await response.body?.cancel();
  if (![401,403,404].includes(response.status)) throw Error('Anonymous private-media access was not denied: ' + response.status);
}
async function revokePrivateMedia(bucket, verifyDenied = denied) {
  if (bucket.name !== BUCKET) throw Error('Unexpected private-media bucket');
  let objects = 0, revokedTokens = 0;
  for (const prefix of ['private_chat/', 'route_albums/', 'route_chat/', 'event_chat/', 'users/']) {
    let query = {prefix, maxResults: 100, autoPaginate: false};
    while (query) {
      const [files, next] = await bucket.getFiles(query);
      for (const file of files) {
        if (!_privatePath(file.name)) continue;
        const [before] = await file.getMetadata();
        const oldTokens = (before.metadata?.firebaseStorageDownloadTokens || '').split(',').filter(Boolean);
        await _sealChatFile(file);
        const url = 'https://firebasestorage.googleapis.com/v0/b/' + BUCKET + '/o/' + encodeURIComponent(file.name) + '?alt=media';
        await verifyDenied(url);
        for (const token of oldTokens) await verifyDenied(url + '&token=' + encodeURIComponent(token));
        objects++;
        revokedTokens += oldTokens.length;
      }
      query = next;
    }
  }
  return {objects, revokedTokens, anonymousAccess: 'denied'};
}
module.exports = {revokePrivateMedia};
if (require.main === module) {
  const {Storage} = require('../functions/node_modules/@google-cloud/storage');
  revokePrivateMedia(new Storage().bucket(BUCKET))
    .then(result => console.log('PRIVATE_MEDIA_SEALED ' + JSON.stringify(result)))
    .catch(error => {console.error('Private-media verification failed', error.code || 'unverified'); process.exitCode = 1;});
}
