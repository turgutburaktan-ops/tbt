import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'auth_switch_stream.dart';

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  Future<void>? _profileUpdateInFlight;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMine() {
    return switchAuthStreamOrEmpty<DocumentSnapshot<Map<String, dynamic>>>(
      auth: _auth,
      signedIn: (user) => _firestore.collection('users').doc(user.uid).snapshots(),
    );
  }

  Future<void> updateProfile({
    required String displayName,
    required String bio,
    File? photo,
  }) {
    final running = _profileUpdateInFlight;
    if (running != null) return running;

    final request = _updateProfileInternal(
      displayName: displayName,
      bio: bio,
      photo: photo,
    );
    _profileUpdateInFlight = request;
    return request.whenComplete(() {
      if (identical(_profileUpdateInFlight, request)) {
        _profileUpdateInFlight = null;
      }
    });
  }

  Future<void> _updateProfileInternal({
    required String displayName,
    required String bio,
    File? photo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Profilini düzenlemek için giriş yapmalısın.');
    }
    final cleanName = displayName.trim();
    final cleanBio = bio.trim();
    if (cleanName.length < 2) {
      throw Exception('Kullanıcı adı en az 2 karakter olmalı.');
    }
    if (cleanBio.length > 160) {
      throw Exception('Açıklama en fazla 160 karakter olabilir.');
    }

    String photoUrl = user.photoURL ?? '';
    if (photo != null) {
      final size = await photo.length();
      if (size <= 0 || size > 15 * 1024 * 1024) {
        throw Exception('Profil fotoğrafı en fazla 15 MB olabilir.');
      }
      final lower = photo.path.toLowerCase();
      final ext = lower.endsWith('.png') ? 'png' : 'jpg';
      final ref = _storage.ref().child('users/${user.uid}/profile/avatar.$ext');
      await ref
          .putFile(
            photo,
            SettableMetadata(
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            ),
          )
          .timeout(const Duration(seconds: 30));
      photoUrl = await ref
          .getDownloadURL()
          .timeout(const Duration(seconds: 8));
    }

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'displayName': cleanName,
      'bio': cleanBio,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));

    unawaited(_syncAuthProfileQuietly(user, cleanName, photoUrl));
  }

  Future<void> _syncAuthProfileQuietly(
    User user,
    String displayName,
    String photoUrl,
  ) async {
    try {
      if ((user.displayName ?? '') != displayName) {
        await user
            .updateDisplayName(displayName)
            .timeout(const Duration(seconds: 6));
      }
      if (photoUrl.isNotEmpty && (user.photoURL ?? '') != photoUrl) {
        await user.updatePhotoURL(photoUrl).timeout(const Duration(seconds: 6));
      }
    } catch (_) {}
  }

  Future<void> updateStudentStatus({required String status}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Öğrenci durumunu değiştirmek için giriş yapmalısın.');
    }
    if (status != 'student' && status != 'non_student') {
      throw Exception('Geçersiz öğrenci durumu.');
    }

    await _firestore.collection('users').doc(user.uid).set({
      'studentStatus': status,
      if (status == 'non_student') ...{
        'campusEligible': false,
        'campusProfileCompleted': false,
        'newStudent2026': false,
        'classYear': '',
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
  }

  Future<void> updateCampusProfile({
    required String university,
    required String faculty,
    required String department,
    required String classYear,
    required List<String> interests,
    bool newStudent2026 = false,
    bool showEducationOnProfile = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Kampüs profilini düzenlemek için giriş yapmalısın.');
    }

    final cleanInterests = interests
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(12)
        .toList();
    final cleanClassYear = classYear.trim();
    const activeStudentYears = <String>{
      'Hazırlık',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
    };
    final campusEligible =
        university.trim().isNotEmpty &&
        activeStudentYears.contains(cleanClassYear);

    await _firestore.collection('users').doc(user.uid).set({
      'university': university.trim(),
      'faculty': faculty.trim(),
      'department': department.trim(),
      'classYear': cleanClassYear,
      'interests': cleanInterests,
      'newStudent2026': campusEligible ? newStudent2026 : false,
      'showEducationOnProfile': showEducationOnProfile,
      'campusProfileCompleted':
          university.trim().isNotEmpty &&
          department.trim().isNotEmpty &&
          cleanInterests.length >= 3,
      'campusEligible': campusEligible,
      'studentStatus': campusEligible
          ? 'student'
          : (cleanClassYear == 'Mezun' ? 'graduate' : 'unknown'),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
  }

  Future<void> completeOnboarding({required bool skipped}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Onboarding için giriş yapmalısın.');
    await _firestore.collection('users').doc(user.uid).set({
      'onboardingRequired': false,
      'onboardingCompleted': true,
      'onboardingSkipped': skipped,
      'onboardingCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
  }
}
