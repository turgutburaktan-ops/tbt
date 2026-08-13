import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PeopleDiscoveryService {
  PeopleDiscoveryService._();
  static final PeopleDiscoveryService instance = PeopleDiscoveryService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const List<String> roles = ['Fotoğrafçı', 'Model', 'Her ikisi'];

  Future<void> ensureProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};
    await ref.set({
      'uid': user.uid,
      'displayName': data['displayName'] ?? user.displayName ?? 'Fotoğrafçı',
      'photoUrl': data['photoUrl'] ?? user.photoURL ?? '',
      'professionalRole': data['professionalRole'] ?? 'Fotoğrafçı',
      'discoverable': data['discoverable'] is bool ? data['discoverable'] : true,
      'city': data['city'] ?? '',
      'portfolioBio': data['portfolioBio'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> myProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  Future<void> updateRole(String role) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    if (!roles.contains(role)) throw Exception('Geçersiz profil türü.');
    await _firestore.collection('users').doc(user.uid).set({
      'professionalRole': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setDiscoverable(bool value) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    await _firestore.collection('users').doc(user.uid).set({
      'discoverable': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<DiscoverablePerson>> watchPeople({String role = 'Tümü'}) {
    final myId = _auth.currentUser?.uid;
    return _firestore.collection('users').limit(120).snapshots().map((snapshot) {
      final result = snapshot.docs
          .where((doc) => doc.id != myId)
          .map(DiscoverablePerson.fromDoc)
          .where((person) => person.discoverable)
          .where((person) => role == 'Tümü' || person.role == role || person.role == 'Her ikisi')
          .toList();
      result.sort((a, b) => a.displayName.compareTo(b.displayName));
      return result;
    });
  }
}

class DiscoverablePerson {
  final String uid;
  final String displayName;
  final String photoUrl;
  final String role;
  final String city;
  final String bio;
  final bool discoverable;

  const DiscoverablePerson({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.role,
    required this.city,
    required this.bio,
    required this.discoverable,
  });

  factory DiscoverablePerson.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return DiscoverablePerson(
      uid: doc.id,
      displayName: (data['displayName'] ?? 'Fotoğrafçı').toString(),
      photoUrl: (data['photoUrl'] ?? '').toString(),
      role: (data['professionalRole'] ?? 'Fotoğrafçı').toString(),
      city: (data['city'] ?? '').toString(),
      bio: (data['portfolioBio'] ?? '').toString(),
      discoverable: data['discoverable'] is bool ? data['discoverable'] as bool : true,
    );
  }
}
