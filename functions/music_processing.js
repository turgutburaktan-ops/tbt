// Shared by production and the actual FFmpeg integration test.
function mixArgs(video, audio, output, mix, hasOriginalAudio) {
 const input=file=>['-protocol_whitelist','file,pipe','-format_whitelist','mov,mp3,aac,wav,ogg','-i',file];
 const filter=hasOriginalAudio
  ? `[1:a]volume=${mix.volume},apad[m];[0:a]volume=${mix.original}[o];[o][m]amix=inputs=2:duration=first:normalize=0[a]`
  : `[1:a]volume=${mix.volume},apad[a]`;
 return [...input(video),'-ss',String(mix.start/1000),'-t',String(mix.duration/1000),...input(audio),
  '-filter_complex',filter,'-map','0:v:0','-map','[a]','-c:v','copy','-c:a','aac','-b:a','192k',
  ...(hasOriginalAudio?[]:['-shortest']),'-t','60','-movflags','+faststart',output];
}
module.exports={mixArgs};
