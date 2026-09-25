const sdk=require('node:module').createRequire(require.resolve('../functions/package.json'));
const {applicationDefault}=sdk('firebase-admin/app');
const fs=require('node:fs');
const credential=applicationDefault();
async function api(url,method='GET',body){
 const token=await credential.getAccessToken();
 const r=await fetch(url,{method,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 const d=await r.json();if(!r.ok)throw Error(`${r.status}: ${d.error?.message||'Google API request failed'}`);return d;
}
(async()=>{
 const service='https://serviceusage.googleapis.com/v1/projects/en-iyi-cekim-noktasi/services/vision.googleapis.com';
 const state=await api(service);
 if(state.state!=='ENABLED') {await api(service+':enable','POST',{});console.log('Vision enable requested');}
 const deadline=Date.now()+180000;while(Date.now()<deadline){if((await api(service)).state==='ENABLED')break;await new Promise(r=>setTimeout(r,5000));}
 const image=fs.readFileSync('assets/spots/hamsilos-tabiat-parki.jpg').toString('base64');
 const d=await api('https://vision.googleapis.com/v1/images:annotate','POST',{requests:[{image:{content:image},features:[{type:'SAFE_SEARCH_DETECTION'}]}]});
 if(d.responses?.[0]?.error)throw Error(d.responses[0].error.message);
 if(!d.responses?.[0]?.safeSearchAnnotation?.adult)throw Error('Vision returned no annotation');
 console.log('Vision API enabled; real benign-photo SafeSearch request succeeded');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
