"""Deploy only explicitly selected callable endpoints; retain existing runtime settings."""
import concurrent.futures,json,os,pathlib,subprocess,urllib.request,urllib.error
project='en-iyi-cekim-noktasi'
def describe(name,region):
 return json.loads(subprocess.check_output(['gcloud','functions','describe',name,'--gen2','--region='+region,'--project='+project,'--format=json']))
base=describe('getAdminInsights','europe-west1')['serviceConfig']
config=base['environmentVariables']['FIREBASE_CONFIG']
assert json.loads(config)['projectId']==project
pathlib.Path('functions/.visibility.gcloudignore').write_text('node_modules/\ntest/\n.git/\n.env*\n*.log\n')
envfile=pathlib.Path(os.environ['RUNNER_TEMP'])/'callable-runtime.json'
envfile.write_text(json.dumps({'FIREBASE_CONFIG':config,'GCLOUD_PROJECT':project}));envfile.chmod(0o600)
new={'registerE2eeIdentity','claimE2eePreKey','sendE2eeMessage'}
names=['getAdminInsights','registerE2eeIdentity','claimE2eePreKey','sendE2eeMessage','chatPrivatePhoto','replyToNotification','chatAction','finalizePrivateMedia','finalizeChatMedia','freezeAccount','unfreezeAccount','deleteAccountNow','socialPublishing','creatorStudio']
def deploy(name):
 region='us-central1' if name=='chatAction' else 'europe-west1'
 args=['gcloud','functions','deploy',name,'--gen2','--region='+region,'--project='+project,'--runtime=nodejs22','--source=functions','--ignore-file=.visibility.gcloudignore','--entry-point='+name,'--trigger-http','--quiet','--format=value(state)']
 if name in new:
  args+=['--env-vars-file='+str(envfile),'--service-account='+base['serviceAccountEmail'],'--allow-unauthenticated','--max-instances=10','--timeout=60s']
 else:
  previous=describe(name,region)
  assert previous['serviceConfig']['environmentVariables'].get('FIREBASE_CONFIG'),name+' missing runtime config'
 subprocess.run(args,check=True)
 result=describe(name,region)
 assert result['state']=='ACTIVE',name+' is not active'
 request=urllib.request.Request(result['serviceConfig']['uri'],data=b'{"data":{}}',headers={'Content-Type':'application/json'})
 try:
  urllib.request.urlopen(request,timeout=30)
  raise RuntimeError(name+' allowed unauthenticated request')
 except urllib.error.HTTPError as error:
  payload=json.loads(error.read())
  assert error.code==401 and payload.get('error',{}).get('status')=='UNAUTHENTICATED',(name,error.code,payload)
 print('CALLABLE_ACTIVE_AUTH_VERIFIED '+name,flush=True)
deploy(names[0])
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for _ in pool.map(deploy,names[1:]):pass
