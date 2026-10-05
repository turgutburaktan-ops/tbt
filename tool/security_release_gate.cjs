const fs = require('node:fs');
const path = require('node:path');
const required = ['private-contacts','frozen-content-reads','end-to-end-encryption','app-check','database-recovery'];
try {
  const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'security_release_readiness.json'), 'utf8'));
  if (!Array.isArray(data.requiredChecks) || data.requiredChecks.length !== required.length) throw Error('Eksik güvenlik kontrol listesi.');
  const blocked = [];
  for (const id of required) {
    const entries = data.requiredChecks.filter(item => item.id === id);
    if (entries.length !== 1) throw Error('Eksik veya yinelenen kontrol: ' + id);
    const check = entries[0];
    if (check.status !== 'verified' || typeof check.evidence !== 'string' || !check.evidence.trim()) {
      blocked.push(id + ': ' + (check.reason || 'Doğrulama kanıtı eksik.'));
    }
  }
  const releaseArg = process.argv.slice(2).join(' ');
  const release = releaseArg === '--release=64' ? 64 : releaseArg === '--release=65' ? 65 : null;
  if (blocked.length && release !== null) {
    const crypto = require('node:crypto');
    const acceptance = JSON.parse(fs.readFileSync(path.join(__dirname, `release${release}_accepted_risks.json`), 'utf8'));
    const actualHash = crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname, 'security_release_readiness.json'))).digest('hex');
    if (acceptance.release !== release || acceptance.version !== ({64: '1.0.36', 65: '1.0.37'})[release] || acceptance.readinessSha256 !== actualHash || JSON.stringify([...acceptance.acceptedChecks].sort()) !== JSON.stringify([...required].sort()) || !acceptance.authorization) throw Error('Release-specific acceptance is missing or stale.');
    console.log(`RELEASE_${release}_ACCEPTED_RISKS_NOT_SECURITY_VERIFIED`);
    blocked.forEach(item => console.log('OPEN_SECURITY_CHECK '+item));
    return;
  }
  if (blocked.length) throw Error('Güvenlik tamamlanmadan mağaza gönderimi engellendi.\n' + blocked.join('\n'));
  console.log('SECURITY_RELEASE_GATE_PASSED');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
