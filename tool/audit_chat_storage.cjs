const fs = require('node:fs');
const {GoogleAuth} = require('../functions/node_modules/google-auth-library');
const {Storage} = require('../functions/node_modules/@google-cloud/storage');
const BUCKET = 'en-iyi-cekim-noktasi.firebasestorage.app';
(async () => {
  const client = await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
  const base = 'https://firebaserules.googleapis.com/v1/projects/en-iyi-cekim-noktasi/';
  const release = (await client.request({url:base+'releases/firebase.storage/'+BUCKET})).data;
  const rules = (await client.request({url:'https://firebaserules.googleapis.com/v1/'+release.rulesetName})).data;
  const text = rules.source.files.map(f=>f.content).join('\n');
  const [files] = await new Storage().bucket(BUCKET).getFiles({prefix:'users/'});
  const chat = files.filter(f=>/^users\/[^/]+\/chat\/[^/]+\/[^/]+$/.test(f.name));
  console.log(JSON.stringify({stage:'READ_ONLY_AUDIT',ruleset:release.rulesetName,
    broadUserMatch:text.includes('match /users/{uid}/{allPaths=**}'),
    publicReadStatements:text.split('\n').filter(l=>l.includes('allow read: if true')).map(l=>l.trim()),
    chatObjects:chat.length,chatObjectsWithTokens:chat.filter(f=>f.metadata.metadata?.firebaseStorageDownloadTokens).length}));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
