import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/user_facing_error.dart';
import '../widgets/firebase_media_image.dart';
import '../widgets/profile_name_link.dart';

class ContentLikesScreen extends StatelessWidget {
  const ContentLikesScreen({super.key, required this.collection, required this.contentId});
  final String collection, contentId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Beğenenler')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(collection).doc(contentId).collection('likes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(userFacingError(snapshot.error!)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final likes = snapshot.data!.docs;
        if (likes.isEmpty) return const Center(child: Text('Henüz beğeni yok.'));
        return ListView.builder(
          itemCount: likes.length,
          itemBuilder: (_, index) {
            final like = likes[index];
            final id = (like.data()['userId'] ?? like.id).toString();
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(id).snapshots(),
              builder: (context, profile) {
                final data = profile.data?.data() ?? <String, dynamic>{};
                final name = (data['displayName'] ?? like.data()['userName'] ?? 'Kullanıcı').toString();
                final username = (data['username'] ?? '').toString();
                return ListTile(
                  onTap: profile.hasError ? null : () => ProfileNameLink.open(context, id),
                  leading: ClipOval(child: SizedBox(width: 48, height: 48,
                    child: FirebaseMediaImage(
                      imageUrl: (data['photoUrl'] ?? '').toString(),
                      fallbackStoragePaths: FirebaseMediaImage.avatarPaths(id),
                      fit: BoxFit.cover,
                      errorWidget: const Icon(Icons.person_outline),
                    ),
                  )),
                  title: Text(name),
                  subtitle: username.isEmpty ? null : Text('@${username.replaceFirst(RegExp(r"^@"), "")}'),
                );
              },
            );
          },
        );
      },
    ),
  );
}
