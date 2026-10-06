const fs=require('node:fs');
(async()=>{
 let out;
 if(process.argv[2]==='apple'){
  const {api,appId}=require('./aso_apple_api.cjs');
  const app=(await api('/apps/'+appId)).data;
  if(app.attributes.bundleId!=='com.tbt.social')throw Error('Unexpected app');
  const versions=(await api('/apps/'+appId+'/appStoreVersions?filter[platform]=IOS&limit=5')).data;
  const infos=(await api('/apps/'+appId+'/appInfos')).data;
  out={versions:[],infos:[]};
  for(const v of versions.slice(0,2)){const ls=(await api('/appStoreVersions/'+v.id+'/appStoreVersionLocalizations')).data;out.versions.push({id:v.id,...v.attributes,localizations:ls});}
  for(const i of infos){const ls=(await api('/appInfos/'+i.id+'/appInfoLocalizations')).data;out.infos.push({id:i.id,...i.attributes,localizations:ls});}
 }else{
  out=await require('./aso_play_api.cjs')(async(req,url)=>({listings:await req(url+'/listings'),tracks:await req(url+'/tracks')}));
 }
 fs.mkdirSync('build/aso',{recursive:true});fs.writeFileSync('build/aso/'+process.argv[2]+'.json',JSON.stringify(out,null,2));
 console.log('ASO_INSPECT '+JSON.stringify(out));
})().catch(e=>{console.error(e.message);if(e.apiMessage)console.error(e.apiMessage);process.exitCode=1;});
