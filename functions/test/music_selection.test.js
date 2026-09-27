const test=require('node:test'), assert=require('node:assert/strict');
const {_selection}=require('../music_v1');
const track={active:true,commercialUseAllowed:true,derivativesAllowed:true,catalogDistributionAllowed:true,audioStoragePath:'music/catalog/test.m4a',durationMs:90000};
test('approved track accepts a 60 second segment',()=>assert.deepEqual(_selection(track,{startMs:30000,clipDurationMs:60000,musicVolume:1,originalAudioVolume:0}),{start:30000,duration:60000,volume:1,original:0}));
test('disabled and unlicensed tracks are rejected',()=>{for(const key of ['active','commercialUseAllowed','derivativesAllowed','catalogDistributionAllowed'])assert.throws(()=>_selection({...track,[key]:false},{}));assert.throws(()=>_selection({...track,audioStoragePath:'users/another/audio.mp3'},{}));assert.throws(()=>_selection(undefined,{}));});
test('out of range times and volume cannot be processed',()=>{for(const d of [{startMs:-1},{startMs:85000,clipDurationMs:15000},{clipDurationMs:60001},{clipDurationMs:-1},{musicVolume:2},{originalAudioVolume:-.1},{startMs:NaN},{musicVolume:'bad'}])assert.throws(()=>_selection(track,d));});
