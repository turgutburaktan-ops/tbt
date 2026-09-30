"""Scoped Cloud Functions deployment, without requesting unrelated Extensions access."""
import os, pathlib, subprocess, concurrent.futures, json
pairs=[('initializePostVisibility','posts/{postId}')]+[(f'initializeVisibility_{c}',c+'/{contentId}') for c in ['stories','post_reposts','social_events','event_memories','travel_plans','communities']]
# Source filtering is local to this deploy and leaves runtime/source settings intact.
pathlib.Path('functions/.visibility.gcloudignore').write_text('node_modules/\ntest/\n.git/\n.env*\n*.log\n')
# Firebase CLI normally injects this config; gcloud does not. Preserve the
# proven live project/bucket configuration without copying secrets.
live=json.loads(subprocess.check_output(['gcloud','functions','describe','getAdminInsights','--gen2','--region=europe-west1','--project=en-iyi-cekim-noktasi','--format=json']))
config=live['serviceConfig']['environmentVariables']['FIREBASE_CONFIG']
assert json.loads(config)['projectId']=='en-iyi-cekim-noktasi'
envfile=pathlib.Path(os.environ['RUNNER_TEMP'])/'visibility-runtime.json'
envfile.write_text(json.dumps({'FIREBASE_CONFIG':config,'GCLOUD_PROJECT':'en-iyi-cekim-noktasi'}))
envfile.chmod(0o600)
def deploy(pair):
 name,pattern=pair
 subprocess.run(['gcloud','functions','deploy',name,'--project=en-iyi-cekim-noktasi','--gen2','--region=europe-west1','--runtime=nodejs22','--source=functions','--ignore-file=.visibility.gcloudignore','--entry-point='+name,'--env-vars-file='+str(envfile),'--service-account='+os.environ['VISIBILITY_RUNTIME_ACCOUNT'],'--trigger-location='+os.environ['VISIBILITY_DATABASE_LOCATION'],'--trigger-event-filters=type=google.cloud.firestore.document.v1.created,database=(default)','--trigger-event-filters-path-pattern=document='+pattern,'--retry','--max-instances=3','--timeout=60s','--quiet','--format=value(state)'],check=True)
 print('VISIBILITY_FUNCTION_ACTIVE '+name,flush=True)
# Validate one deployment before starting the remaining independent functions.
deploy(pairs[0])
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for _ in pool.map(deploy,pairs[1:]):pass
