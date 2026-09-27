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
  if (blocked.length) throw Error('Güvenlik tamamlanmadan mağaza gönderimi engellendi.\n' + blocked.join('\n'));
  console.log('SECURITY_RELEASE_GATE_PASSED');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
