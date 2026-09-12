import 'package:flutter_test/flutter_test.dart';
import '../lib/models/profile_identity.dart';

void main() {
  test('new and self-selected profiles remain personal', () {
    expect(ProfileIdentity.label({}), 'Kişisel');
    for (final type in ['creator', 'explorer', 'business_owner', 'organizer']) {
      expect(ProfileIdentity.label({'profileType': type}), 'Kişisel');
    }
  });

  test('only an active journey role changes the displayed identity', () {
    expect(ProfileIdentity.label({
      'accountTypes': {'creator': {'active': false}},
      'profileType': 'creator',
    }), 'Kişisel');
    for (final entry in ProfileIdentity.labels.entries) {
      expect(ProfileIdentity.label({
        'accountTypes': {entry.key: {'active': true}},
      }), entry.value);
    }
  });

  test('selected earned badge is preferred; unearned selection is ignored', () {
    expect(ProfileIdentity.label({
      'selectedBadgeIds': ['creator', 'social'],
      'accountTypes': {
        'creator': {'active': false},
        'explorer': {'active': true},
        'social': {'active': true},
      },
    }), 'TBT Sosyal');
  });

  test('existing server-granted Creator invitations retain their identity', () {
    expect(ProfileIdentity.label({'isCreator': true}), 'TBT Creator');
  });

  test('reputation role fallback works without accountTypes', () {
    expect(ProfileIdentity.label({
      'reputation': {'roles': {'gourmet': {'active': true}}},
    }), 'TBT Gurme');
  });
}
