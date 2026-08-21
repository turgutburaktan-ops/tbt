import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMine() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  Future<void> updateProfile({
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
      final lower = photo.path.toLowerCase();
      final ext = lower.endsWith('.png') ? 'png' : 'jpg';
      final ref = _storage.ref().child('users/${user.uid}/profile/avatar.$ext');
      final task = await ref.putFile(
        photo,
        SettableMetadata(
          contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
        ),
      );
      photoUrl = await task.ref.getDownloadURL();
    }

    await user.updateDisplayName(cleanName);
    if (photoUrl.isNotEmpty) await user.updatePhotoURL(photoUrl);
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'displayName': cleanName,
      'bio': cleanBio,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final campusEligible = university.trim().isNotEmpty &&
        activeStudentYears.contains(cleanClassYear);

    await _firestore.collection('users').doc(user.uid).set({
      'university': university.trim(),
      'faculty': faculty.trim(),
      'department': department.trim(),
      'classYear': cleanClassYear,
      'interests': cleanInterests,
      'newStudent2026': campusEligible ? newStudent2026 : false,
      'showEducationOnProfile': showEducationOnProfile,
      'campusProfileCompleted': university.trim().isNotEmpty &&
          department.trim().isNotEmpty &&
          cleanInterests.length >= 3,
      'campusEligible': campusEligible,
      'studentStatus': campusEligible
          ? 'student'
          : (cleanClassYear == 'Mezun' ? 'graduate' : 'unknown'),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    }, SetOptions(merge: true));
  }
}
