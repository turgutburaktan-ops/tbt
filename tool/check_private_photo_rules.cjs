const fs = require('node:fs');
const {GoogleAuth} = require('../functions/node_modules/google-auth-library');
(async () => {
  const client = await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
  const base = 'https://firebaserules.googleapis.com/v1/';
  const project = 'projects/en-iyi-cekim-noktasi';
  const release = (await client.request({url:base+project+'/releases/cloud.firestore'})).data;
  const rules = (await client.request({url:base+release.rulesetName})).data;
  if (rules.source.files.length !== 1) throw Error('Unexpected live rules layout');
  fs.writeFileSync('firestore.rules', rules.source.files[0].content);
  console.log('Fetched live Firestore policy for private photo denial tests; no rules changed.');
})().catch(error => { console.error(error.message); process.exitCode=1; });
