const {test} = require('node:test');
const assert = require('node:assert/strict');
const {configurationVerified} = require('../../tool/project_security_status.cjs');
const verified = () => ({
  passwordPolicy: {enforcement: 'ENFORCE', minimumLength: 10},
  databaseRecovery: {pointInTimeRecoveryEnablement: 'POINT_IN_TIME_RECOVERY_ENABLED', deleteProtectionState: 'DELETE_PROTECTION_ENABLED'},
});
test('configuration success requires verified password and both recovery protections', () => {
  assert.equal(configurationVerified(verified()), true);
  for (const summary of [undefined, {}, {...verified(), databaseRecovery: {completed: false, status: 403}}, {...verified(), passwordPolicy: {completed: false, status: 403}}]) {
    assert.equal(configurationVerified(summary), false);
  }
  for (const key of Object.keys(verified().databaseRecovery)) {
    const summary = verified();
    summary.databaseRecovery[key] = 'DISABLED';
    assert.equal(configurationVerified(summary), false);
  }
  for (const minimumLength of [9, null, '10', NaN]) {
    const summary = verified();
    summary.passwordPolicy.minimumLength = minimumLength;
    assert.equal(configurationVerified(summary), false);
  }
});
