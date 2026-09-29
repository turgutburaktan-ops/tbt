// A successful process must mean both requested protections were read back.
function configurationVerified(summary) {
  return summary?.passwordPolicy?.enforcement === 'ENFORCE' &&
    Number.isInteger(summary.passwordPolicy.minimumLength) &&
    summary.passwordPolicy.minimumLength >= 10 &&
    summary?.databaseRecovery?.pointInTimeRecoveryEnablement === 'POINT_IN_TIME_RECOVERY_ENABLED' &&
    summary.databaseRecovery.deleteProtectionState === 'DELETE_PROTECTION_ENABLED';
}
module.exports = {configurationVerified};
