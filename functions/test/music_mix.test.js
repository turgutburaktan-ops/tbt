const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {execFileSync}=require('node:child_process');
const ffmpeg=require('ffmpeg-static');
const run=args=>execFileSync(ffmpeg,['-nostdin','-y','-v','error',...args]);
const videoHash=file=>run(['-i',file,'-map','0:v:0','-c','copy','-f','hash','-hash','sha256','-']).toString().trim();
test('adding music preserves encoded video bytes with and without source audio',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'music-test-'));
 try {
  const audio=path.join(dir,'music.m4a');run(['-f','lavfi','-i','sine=frequency=500:duration=2','-c:a','aac',audio]);
  for(const withAudio of [true,false]){
   const input=path.join(dir,`input-${withAudio}.mp4`),output=path.join(dir,`output-${withAudio}.mp4`);
   run(['-f','lavfi','-i','color=c=blue:s=1080x1920:r=24:d=2',...(withAudio?['-f','lavfi','-i','sine=frequency=200:duration=2']:[]),'-c:v','libx264','-preset','ultrafast',...(withAudio?['-c:a','aac']:[]),input]);
   const filter=withAudio?'[1:a]volume=.85,apad[m];[0:a]volume=.25[o];[o][m]amix=inputs=2:duration=first:normalize=0[a]':'[1:a]volume=.85,apad[a]';
   run(['-i',input,'-i',audio,'-filter_complex',filter,'-map','0:v:0','-map','[a]','-c:v','copy','-c:a','aac','-b:a','192k','-shortest','-t','60',output]);
   assert.equal(videoHash(output),videoHash(input));
   assert.ok(run(['-i',output,'-map','0:a:0','-f','s16le','-']).length>1000);
  }
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
