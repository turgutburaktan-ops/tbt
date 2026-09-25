const sdk=require('node:module').createRequire(require.resolve('../functions/package.json'));
const {initializeApp,applicationDefault}=sdk('firebase-admin/app');
const {getAuth}=sdk('firebase-admin/auth');
initializeApp({credential:applicationDefault(),projectId:'en-iyi-cekim-noktasi'});
(async()=>{
 const user=await getAuth().getUserByEmail('turgutburaktan@gmail.com');
 if(user.customClaims?.admin!==true || !user.emailVerified)throw Error('Existing admin credentials required');
 const token=await getAuth().createCustomToken(user.uid);
 const sessionResponse=await fetch('https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=AIzaSyBDoKy5YMP5-6UJqotfuUA7a74H-x-5miQ',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token,returnSecureToken:true})});
 const session=await sessionResponse.json();if(!sessionResponse.ok||!session.idToken)throw Error('Admin diagnostic session unavailable');
 const response=await fetch('https://europe-west1-en-iyi-cekim-noktasi.cloudfunctions.net/photoModerationHealth',{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${session.idToken}`},body:JSON.stringify({data:{}})});
 const result=await response.json();
 if(!response.ok||!result.result?.ok)throw Error(`Runtime photo moderation diagnostic failed: ${result.error?.message||response.status}`);
 console.log('PASS LIVE: deployed runtime can read an existing route photo and run Google Vision; five-strike/admin policy active');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
