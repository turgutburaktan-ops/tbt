// Read-only compatibility evidence. Never enable enforcement from aggregate counts.
const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
(async()=>{
 const project='en-iyi-cekim-noktasi';
 const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/monitoring.read','https://www.googleapis.com/auth/logging.read']}).getClient();
 const end=new Date(),start=new Date(end.getTime()-24*60*60*1000);
 const counts=new Map();let pageToken;
 try {
  do {
   const result=(await client.request({url:`https://monitoring.googleapis.com/v3/projects/${project}/timeSeries`,params:{
    filter:'metric.type="firebaseappcheck.googleapis.com/services/verification_count"',
    'interval.startTime':start.toISOString(),'interval.endTime':end.toISOString(),
    'aggregation.alignmentPeriod':'86400s','aggregation.perSeriesAligner':'ALIGN_SUM',
    pageSize:1000,...(pageToken?{pageToken}:{}),
   }})).data;
   for(const series of result.timeSeries||[]) {
    const labels=series.metric?.labels||{};
    const key=JSON.stringify({appId:labels.app_id||'unknown',security:labels.security||'unknown',result:labels.result||'unknown',service:series.resource?.labels?.service||series.resource?.labels?.service_id||'unknown'});
    counts.set(key,(counts.get(key)||0)+(series.points||[]).reduce((sum,p)=>sum+Number(p.value?.int64Value||0),0));
   }
   pageToken=result.nextPageToken;
  }while(pageToken);
  console.log('APP_CHECK_METRICS '+JSON.stringify({hours:24,series:[...counts].map(([key,count])=>({...JSON.parse(key),count})),enforcementChanged:false}));
 }catch(e){console.log('APP_CHECK_METRICS '+JSON.stringify({completed:false,status:e.response?.status||e.code,enforcementChanged:false}));}
 const verdicts={};let seen=0,truncated=false;
 try {
  pageToken=undefined;
  do {
   const result=(await client.request({url:'https://logging.googleapis.com/v2/entries:list',method:'POST',data:{
    resourceNames:[`projects/${project}`],filter:`labels."firebase-log-type"="callable-request-verification" AND timestamp>="${start.toISOString()}"`,
    pageSize:1000,...(pageToken?{pageToken}:{}),
   }})).data;
   for(const entry of result.entries||[]) {
    const v=entry.jsonPayload?.verifications||{};
    const app=['VALID','INVALID','MISSING'].includes(v.app)?v.app:'OTHER';
    const auth=['VALID','INVALID','MISSING'].includes(v.auth)?v.auth:'OTHER';
    const key=`app:${app},auth:${auth}`;
    verdicts[key]=(verdicts[key]||0)+1;seen++;
   }
   pageToken=result.nextPageToken;
   if(seen>=20000&&pageToken){truncated=true;break;}
  }while(pageToken);
  console.log('CALLABLE_CHECK_METRICS '+JSON.stringify({hours:24,verdicts,sampled:seen,truncated}));
 }catch(e){console.log('CALLABLE_CHECK_METRICS '+JSON.stringify({completed:false,status:e.response?.status||e.code}));}
})().catch(e=>{console.error('Readiness check failed',e.response?.status||e.code);process.exitCode=1;});
