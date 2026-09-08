"""Check the guarded patch against a supplied, unmodified website app.js."""
import json
from pathlib import Path
import subprocess
import sys
from patch_shared_spot_web import patch

source = patch(Path(sys.argv[1]).read_text())
subprocess.run(['node', '--input-type=module', '--check'], input=source, text=True, check=True)

def function(start, end):
    return source[source.index(start):source.index(end, source.index(start))]

snippets = '\n'.join([
    next(line for line in source.splitlines() if line.startswith('function esc(')),
    next(line for line in source.splitlines() if line.startswith('function pageHead(')),
    function('function spotPhotoCredit(s){','function sortNearby('),
])
test = '''
const vm=require('node:vm'), assert=require('node:assert/strict');
const spot={id:'id#1',name:'<img src=x onerror=alert(1)>',city:'<script>bad</script>',category:'<b>category</b>',best:'<i>best</i>',image:'https://example.org/image.jpg?x="bad',rating:4,lat:38,lng:39};
const grid={innerHTML:'',querySelectorAll:()=>[]};
const context={URL,spots:[spot],selectedStops:[],searchText:'',app:{innerHTML:''},
  document:{querySelector:()=>grid},toast:()=>{},location:{hash:''},shareLink:()=>{}};
vm.createContext(context);
vm.runInContext(SNIPPETS,context);
vm.runInContext('drawSpots(spots)',context);
assert.equal(vm.runInContext("spotPhotoCredit({imageSourcePage:'javascript:alert(1)'})",context),'');
const credit=vm.runInContext("spotPhotoCredit({imageSourcePage:'https://commons.wikimedia.org/wiki/File:Test.jpg',imageAuthor:'<script>bad</script>',imageLicense:'CC BY-SA 4.0'})",context);
assert.ok(credit.includes('&lt;script&gt;'));
assert.ok(!credit.includes('<script>'));
assert.ok(grid.innerHTML.includes('&lt;img'));
assert.ok(!grid.innerHTML.includes('<script>bad'));
assert.ok(grid.innerHTML.includes('id%231'));
(async()=>{
  await vm.runInContext('renderPlaceDetail(spots[0].id)',context);
  assert.ok(context.app.innerHTML.includes('&lt;img'));
  assert.ok(!context.app.innerHTML.includes('<script>bad'));
  console.log('PASS: live web patch parses and remote catalog HTML is escaped.');
})().catch(e=>{console.error(e);process.exitCode=1;});
'''.replace('SNIPPETS', json.dumps(snippets))
subprocess.run(['node'], input=test, text=True, check=True)
