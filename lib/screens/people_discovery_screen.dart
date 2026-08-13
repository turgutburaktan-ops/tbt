import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/people_discovery_service.dart';
import 'chat_screen.dart';

class PeopleDiscoveryScreen extends StatefulWidget {
  const PeopleDiscoveryScreen({super.key});

  @override
  State<PeopleDiscoveryScreen> createState() => _PeopleDiscoveryScreenState();
}

class _PeopleDiscoveryScreenState extends State<PeopleDiscoveryScreen> {
  String _filter = 'Tümü';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    PeopleDiscoveryService.instance.ensureProfile();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
        title: const Text('Fotoğrafçı & Model'),
      ),
      body: !signedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Fotoğrafçı ve modelleri keşfetmek için giriş yapmalısın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            )
          : Column(
              children: [
                _myRoleCard(),
                SizedBox(
                  height: 54,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    children: ['Tümü', ...PeopleDiscoveryService.roles]
                        .map(
                          (role) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(role),
                              selected: _filter == role,
                              onSelected: (_) => setState(() => _filter = role),
                              selectedColor: const Color(0xFFFFC107),
                              labelStyle: TextStyle(
                                color: _filter == role ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<DiscoverablePerson>>(
                    stream: PeopleDiscoveryService.instance.watchPeople(role: _filter),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Kullanıcılar yüklenemedi. Bağlantını kontrol edip tekrar dene.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                        );
                      }
                      final people = snapshot.data ?? const <DiscoverablePerson>[];
                      if (people.isEmpty) {
                        return const Center(
                          child: Text(
                            'Bu filtrede henüz görünür profil yok.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                        itemCount: people.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _personCard(people[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _myRoleCard() {
    return StreamBuilder(
      stream: PeopleDiscoveryService.instance.myProfile(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final role = (data['professionalRole'] ?? 'Fotoğrafçı').toString();
        final discoverable = data['discoverable'] is bool ? data['discoverable'] as bool : true;
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF151A22),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Benim profil türüm', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PeopleDiscoveryService.roles
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item),
                        selected: role == item,
                        onSelected: _saving ? null : (_) => _setRole(item),
                      ),
                    )
                    .toList(),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Keşfette görün'),
                subtitle: const Text(
                  'Kapattığında diğer kullanıcılar seni bu listede göremez.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: discoverable,
                onChanged: _saving ? null : _setDiscoverable,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _personCard(DiscoverablePerson person) {
    return Card(
      color: const Color(0xFF151A22),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFF222831),
          backgroundImage: person.photoUrl.isNotEmpty ? NetworkImage(person.photoUrl) : null,
          child: person.photoUrl.isEmpty
              ? const Icon(Icons.person_outline, color: Colors.white54)
              : null,
        ),
        title: Text(person.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          [
            person.role,
            if (person.city.isNotEmpty) person.city,
            if (person.bio.isNotEmpty) person.bio,
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: IconButton(
          tooltip: 'Mesaj gönder',
          icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFFC107)),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(otherUserId: person.uid),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setRole(String role) async {
    setState(() => _saving = true);
    try {
      await PeopleDiscoveryService.instance.updateRole(role);
    } catch (e) {
      if (mounted) _message(_cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setDiscoverable(bool value) async {
    setState(() => _saving = true);
    try {
      await PeopleDiscoveryService.instance.setDiscoverable(value);
    } catch (e) {
      if (mounted) _message(_cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _cleanError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }
}
