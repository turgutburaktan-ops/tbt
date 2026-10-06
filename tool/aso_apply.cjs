const fs=require('node:fs');
const m=require('../store/aso/tr-TR/metadata.json');
const save=(name,data)=>{fs.mkdirSync('build/aso',{recursive:true});fs.writeFileSync('build/aso/'+name+'.json',JSON.stringify(data,null,2));};
const equal=(actual,expected)=>{for(const [k,v] of Object.entries(expected))if(actual[k]!==v)throw Error('Readback mismatch: '+k);};
(async()=>{
 if(m.title.length>30||m.shortDescription.length>80||m.subtitle.length>30||m.description.length>4000||m.promotionalText.length>170||Buffer.byteLength(m.keywords)>100)throw Error('Metadata exceeds store limits');
 if(process.argv[2]==='play'){
  const withEdit=require('./aso_play_api.cjs');
  const expected={title:m.title,shortDescription:m.shortDescription,fullDescription:m.description};
  await withEdit(async(req,url)=>{
   const before=await req(url+'/listings/tr-TR');save('play-before',before);
   const tracks=await req(url+'/tracks');
   if(before.title!=='TBT'&&before.title!==m.title)throw Error('Store title changed since inspection');
   await req(url+'/listings/tr-TR','PATCH',expected);
   equal(await req(url+'/listings/tr-TR'),expected);
   if(JSON.stringify(await req(url+'/tracks'))!==JSON.stringify(tracks))throw Error('Tracks changed in metadata edit');
   await req(url+':validate','POST');
   await req(url+':commit?changesInReviewBehavior=ERROR_IF_IN_REVIEW','POST');
  });
  await withEdit(async(req,url)=>{const after=await req(url+'/listings/tr-TR');equal(after,expected);save('play-after',after);console.log('PLAY_ASO_COMMITTED_AND_READ_BACK '+JSON.stringify(after));});
 }else if(process.argv[2]==='apple'){
  const {api,appId}=require('./aso_apple_api.cjs');
  const versions=(await api('/apps/'+appId+'/appStoreVersions?filter[platform]=IOS&limit=20')).data;
  const current=versions.find(v=>v.attributes.versionString==='1.0.37');
  if(!current||!['READY_FOR_SALE','READY_FOR_DISTRIBUTION'].includes(current.attributes.appStoreState))throw Error('Live version state changed');
  const locs=(await api('/appStoreVersions/'+current.id+'/appStoreVersionLocalizations')).data;
  const loc=locs.find(l=>l.attributes.locale==='tr');if(!loc)throw Error('Turkish localization missing');
  save('apple-live-before',loc);
  await api('/appStoreVersionLocalizations/'+loc.id,'PATCH',{data:{type:'appStoreVersionLocalizations',id:loc.id,attributes:{promotionalText:m.promotionalText}}});
  const live=(await api('/appStoreVersionLocalizations/'+loc.id)).data;equal(live.attributes,{promotionalText:m.promotionalText});save('apple-live-after',live);console.log('APPLE_LIVE_PROMOTIONAL_TEXT_VERIFIED');
  let draft=versions.find(v=>v.attributes.versionString==='1.0.38');
  if(!draft){
   const active=versions.filter(v=>!['READY_FOR_SALE','READY_FOR_DISTRIBUTION','REPLACED_WITH_NEW_VERSION','REMOVED_FROM_SALE','DEVELOPER_REMOVED_FROM_SALE'].includes(v.attributes.appStoreState));
   if(active.length)throw Error('Another active Apple version exists');
   draft=(await api('/appStoreVersions','POST',{data:{type:'appStoreVersions',attributes:{platform:'IOS',versionString:'1.0.38',releaseType:'AFTER_APPROVAL',copyright:'2026 TBT'},relationships:{app:{data:{type:'apps',id:appId}}}}})).data;
  }
  if(draft.attributes.appStoreState!=='PREPARE_FOR_SUBMISSION')throw Error('Draft is not editable');
  const dl=(await api('/appStoreVersions/'+draft.id+'/appStoreVersionLocalizations')).data.find(l=>l.attributes.locale==='tr');
  if(!dl)throw Error('Draft Turkish localization missing');save('apple-draft-before',dl);
  const attrs={description:m.description,keywords:m.keywords,promotionalText:m.promotionalText};
  await api('/appStoreVersionLocalizations/'+dl.id,'PATCH',{data:{type:'appStoreVersionLocalizations',id:dl.id,attributes:attrs}});
  const read=(await api('/appStoreVersionLocalizations/'+dl.id)).data;equal(read.attributes,attrs);save('apple-draft-after',read);
  const infos=(await api('/apps/'+appId+'/appInfos')).data;
  const info=infos.find(i=>i.attributes.appStoreState==='PREPARE_FOR_SUBMISSION'||i.attributes.state==='PREPARE_FOR_SUBMISSION');
  if(!info)throw Error('Editable app information not found');
  const il=(await api('/appInfos/'+info.id+'/appInfoLocalizations')).data.find(l=>l.attributes.locale==='tr');
  if(!il)throw Error('Editable Turkish app info missing');save('apple-info-before',il);
  const ia={name:m.title,subtitle:m.subtitle};
  await api('/appInfoLocalizations/'+il.id,'PATCH',{data:{type:'appInfoLocalizations',id:il.id,attributes:ia}});
  const ir=(await api('/appInfoLocalizations/'+il.id)).data;equal(ir.attributes,ia);save('apple-info-after',ir);
  console.log('APPLE_ASO_DRAFT_VERIFIED '+JSON.stringify({version:'1.0.38',versionId:draft.id,state:'PREPARE_FOR_SUBMISSION',title:ir.attributes.name,subtitle:ir.attributes.subtitle,keywords:read.attributes.keywords}));
 }
})().catch(e=>{console.error(e.message);if(e.apiMessage)console.error(e.apiMessage);process.exitCode=1;});
