/// Public identity comes from the server-managed journey, never profileType.
class ProfileIdentity {
  ProfileIdentity._();

  static const labels = <String, String>{
    'creator': 'TBT Creator',
    'explorer': 'TBT Kâşif',
    'social': 'TBT Sosyal',
    'gourmet': 'TBT Gurme',
  };

  static String type(Map<String, dynamic> profile) {
    final reputation = profile['reputation'];
    final rawRoles = profile['accountTypes'] ??
        (reputation is Map ? reputation['roles'] : null);
    // Older redeemed Creator invitations predate accountTypes.
    if (rawRoles == null && profile['isCreator'] == true) return 'creator';
    final roles = rawRoles is Map ? rawRoles : const {};
    final selected = profile['selectedBadgeIds'];
    final order = <String>{
      if (selected is List) ...selected.map((value) => value.toString()),
      ...labels.keys,
    };
    for (final role in order) {
      if (!labels.containsKey(role)) continue;
      final state = roles[role];
      if (state is Map && state['active'] == true) return role;
    }
    return 'personal';
  }

  static String label(Map<String, dynamic> profile) =>
      labels[type(profile)] ?? 'Kişisel';
}
