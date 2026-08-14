import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MentionProfileScreen extends StatelessWidget {
  final String userId;

  const MentionProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final postsQuery = FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: userId);

    return Scaffold(
      backgroundColor: const Color(0xFF090812),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090812),
        foregroundColor: Colors.white,
        title: const Text('Profil'),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: userRef.get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = userSnapshot.data?.data();
          if (data == null) {
            return const Center(child: Text('Kullanıcı bulunamadı.'));
          }

          final displayName = (data['displayName'] ?? data['username'] ?? 'Fotoğrafçı').toString();
          final username = (data['username'] ?? displayName).toString();
          final bio = (data['bio'] ?? '').toString().trim();
          final photoUrl = (data['photoUrl'] ?? '').toString();

          return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: postsQuery.get(),
            builder: (context, postsSnapshot) {
              final posts = postsSnapshot.data?.docs ?? const [];
              return ListView(
                padding: const EdgeInsets.only(bottom: 36),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: const Color(0xFF1C1733),
                            backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
                            child: photoUrl.isEmpty
                                ? const Icon(Icons.person, size: 38, color: Colors.white54)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@${username.replaceFirst('@', '')}',
                                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              if (displayName != username)
                                Text(displayName, style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 10),
                              Text('${posts.length} gönderi', style: const TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: Text(bio, style: const TextStyle(color: Colors.white70, height: 1.45)),
                    ),
                  const Divider(height: 1, color: Color(0xFF241A3A)),
                  if (postsSnapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('Henüz gönderi yok.', style: TextStyle(color: Colors.white54))),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(2),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index].data();
                        final imageUrl = (post['imageUrl'] ?? '').toString();
                        return Container(
                          color: const Color(0xFF141126),
                          child: imageUrl.isEmpty
                              ? const Icon(Icons.image_outlined, color: Colors.white24)
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white24),
                                ),
                        );
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
