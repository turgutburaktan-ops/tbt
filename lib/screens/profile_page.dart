import 'create_post_screen.dart';
import 'my_posts_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import 'login_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFC107),
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return _LoggedOutProfile(
            onLogin: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
              );
            },
          );
        }

        return _LoggedInProfile(
          user: user,
        );
      },
    );
  }
}

class _LoggedOutProfile extends StatelessWidget {
  final VoidCallback onLogin;

  const _LoggedOutProfile({
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          22,
          20,
          110,
        ),
        children: [
          const Text(
            'Profil',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 60),

          const Center(
            child: CircleAvatar(
              radius: 58,
              backgroundColor: Color(0xFFFFC107),
              child: CircleAvatar(
                radius: 52,
                backgroundColor: Color(0xFF171C24),
                child: Icon(
                  Icons.person_outline,
                  size: 62,
                  color: Colors.white54,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Hesabına giriş yap',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Fotoğraf paylaşmak, çekimlerini kaydetmek ve topluluğa katılmak için giriş yap veya yeni hesap oluştur.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: onLogin,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(
                Icons.login_rounded,
              ),
              label: const Text(
                'Giriş Yap / Kayıt Ol',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoggedInProfile extends StatelessWidget {
  final User user;

  const _LoggedInProfile({
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        user.displayName?.trim().isNotEmpty == true
            ? user.displayName!
            : 'Fotoğrafçı';

    final email = user.email ?? '';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          22,
          20,
          110,
        ),
        children: [
          const Text(
            'Profil',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 24),

          const Center(
            child: CircleAvatar(
              radius: 54,
              backgroundColor: Color(0xFFFFC107),
              child: CircleAvatar(
                radius: 49,
                backgroundColor: Color(0xFF171C24),
                child: Icon(
                  Icons.person,
                  size: 56,
                  color: Colors.white54,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          Center(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 6),

          Center(
            child: Text(
              email,
              style: const TextStyle(
                color: Colors.white54,
              ),
            ),
          ),

          const SizedBox(height: 26),

          ValueListenableBuilder<List<PhotoSpot>>(
            valueListenable:
                FavoritesService.savedSpots,
            builder: (
              context,
              saved,
              child,
            ) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF151A22),
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: [
                    const _ProfileStat(
                      value: '0',
                      label: 'Çekim',
                    ),
                    _ProfileStat(
                      value: saved.length.toString(),
                      label: 'Kaydedilen',
                    ),
                    _ProfileStat(
                      value: saved.length.toString(),
                      label: 'Favori',
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          _MenuItem(
            icon: Icons.photo_library_outlined,
            title: 'Çekimlerim',
            subtitle:
                'Paylaştığın fotoğrafları görüntüle',
            onTap: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'Fotoğraf paylaşım sistemi birazdan eklenecek.',
                  ),
                ),
              );
            },
          ),

          _MenuItem(
            icon: Icons.favorite_border,
            title: 'Kaydedilen Noktalar',
            subtitle:
                'Favori çekim noktalarını görüntüle',
            onTap: () {},
          ),

          _MenuItem(
            icon: Icons.location_on_outlined,
            title: 'Konum Tercihleri',
            subtitle:
                'Yakındaki çekim noktalarını yönet',
            onTap: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'GPS özelliğini sıradaki aşamada ekleyeceğiz.',
                  ),
                ),
              );
            },
          ),

          _MenuItem(
            icon: Icons.logout_rounded,
            title: 'Çıkış Yap',
            subtitle: 'Hesabından çık',
            onTap: () async {
              await AuthService.instance.logout();
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStat({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFFFC107),
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      color: const Color(0xFF151A22),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC107)
                .withOpacity(.12),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFFC107),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white38,
        ),
        onTap: onTap,
      ),
    );
  }
}
