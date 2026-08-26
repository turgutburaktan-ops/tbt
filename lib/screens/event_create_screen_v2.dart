import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/social_event.dart';
import '../services/event_privacy_service.dart';
import '../services/event_trust_service.dart';
import '../services/social_event_service.dart';
import '../theme/app_theme.dart';
import 'event_location_picker_screen.dart';

class EventCreateScreenV2 extends StatefulWidget {
  final String initialTitle;
  final String initialCity;
  final String initialLocationLabel;
  final String initialDescription;
  final int initialCapacity;
  final DateTime? initialStartsAt;
  final SocialEventType initialType;
  final double? initialLatitude;
  final double? initialLongitude;

  const EventCreateScreenV2({
    super.key,
    this.initialTitle = '',
    this.initialCity = '',
    this.initialLocationLabel = '',
    this.initialDescription = '',
    this.initialCapacity = 10,
    this.initialStartsAt,
    this.initialType = SocialEventType.social,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<EventCreateScreenV2> createState() => _EventCreateScreenV2State();
}

class _EventCreateScreenV2State extends State<EventCreateScreenV2> {
  late final TextEditingController _title;
  late final TextEditingController _city;
  late final TextEditingController _location;
  late final TextEditingController _description;
  final _customType = TextEditingController();
  late final TextEditingController _capacity;
  final _picker = ImagePicker();

  File? _image;
  late DateTime _startsAt;
  late SocialEventType _type;
  EventVisibility _visibility = EventVisibility.public;
  Map<String, String> _selectedPeople = {};
  EventLocationSelection? _selectedLocation;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    _city = TextEditingController(text: widget.initialCity);
    _location = TextEditingController(text: widget.initialLocationLabel);
    _description = TextEditingController(text: widget.initialDescription);
    _capacity = TextEditingController(text: widget.initialCapacity.toString());
    _startsAt =
        widget.initialStartsAt ?? DateTime.now().add(const Duration(hours: 2));
    _type = widget.initialType;
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = EventLocationSelection(
        latitude: widget.initialLatitude!,
        longitude: widget.initialLongitude!,
        label: widget.initialLocationLabel,
      );
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _city,
      _location,
      _description,
      _customType,
      _capacity,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1800,
      requestFullMetadata: false,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _image = File(picked.path);
      _error = null;
    });
  }

  Future<void> _chooseImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Fotoğraf çek'),
            onTap: () => Navigator.pop(sheet, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galeriden seç'),
            onTap: () => Navigator.pop(sheet, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _chooseDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _chooseLocation() async {
    final result = await Navigator.push<EventLocationSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => EventLocationPickerScreen(
          city: _city.text,
          addressLabel: _location.text,
          initialLatitude: _selectedLocation?.latitude,
          initialLongitude: _selectedLocation?.longitude,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedLocation = result;
      if (_location.text.trim().isEmpty) _location.text = result.label;
      _error = null;
    });
  }

  Future<Map<String, String>> _pickPeople(Set<String> initial) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final selected = <String>{...initial};
    final names = <String, String>{};
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Kişileri Seç',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheet, {
                        for (final id in selected) id: names[id] ?? 'Kullanıcı',
                      }),
                      child: Text('Bitti (${selected.length})'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder(
                  stream: EventPrivacyService.instance.users(),
                  builder: (_, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs
                        .where((d) => d.id != me)
                        .toList();
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final name =
                            (data['displayName'] ??
                                    data['email'] ??
                                    'Kullanıcı')
                                .toString();
                        names[doc.id] = name;
                        final checked = selected.contains(doc.id);
                        return CheckboxListTile(
                          value: checked,
                          title: Text(name),
                          onChanged: (value) => setSheetState(() {
                            if (value == true) {
                              selected.add(doc.id);
                            } else {
                              selected.remove(doc.id);
                            }
                          }),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? {for (final id in initial) id: names[id] ?? 'Kullanıcı'};
  }

  String _dateLabel() {
    final d = _startsAt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  IconData _visibilityIcon(EventVisibility value) => switch (value) {
    EventVisibility.public => Icons.public,
    EventVisibility.followers => Icons.people_outline,
    EventVisibility.mutuals => Icons.sync_alt,
    EventVisibility.closeFriends => Icons.star_outline,
    EventVisibility.selectedPeople => Icons.person_add_alt_1,
    EventVisibility.private => Icons.lock_outline,
  };

  Future<void> _save() async {
    if (_saving) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message('Etkinlik oluşturmak için giriş yapmalısın.');
      return;
    }
    final capacity = int.tryParse(_capacity.text.trim()) ?? 0;
    if (_image == null) {
      setState(() => _error = 'Etkinlik için bir kapak fotoğrafı ekle.');
      return;
    }
    if (capacity < 1) {
      setState(() => _error = 'Katılımcı kapasitesi en az 1 olmalı.');
      return;
    }
    if (_selectedLocation == null) {
      setState(() => _error = 'Haritadan kesin konumu seç.');
      return;
    }
    if (_visibility == EventVisibility.selectedPeople &&
        _selectedPeople.isEmpty) {
      setState(() => _error = 'En az bir kişi seçmelisin.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    String? uploadedPath;
    try {
      final allowed = await EventPrivacyService.instance.resolveAudience(
        _visibility,
        selectedUserIds: _selectedPeople.keys.toList(),
      );

      final eventId = await SocialEventService.instance.create(
        title: _title.text,
        type: _type,
        startsAt: _startsAt,
        capacity: capacity,
        city: _city.text,
        locationLabel: _location.text,
        description: _description.text,
        customTypeLabel: _customType.text,
        accessType: EventAccessType.free,
        ticketPriceMinor: 0,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        visibility: _visibility,
        allowedUserIds: allowed,
      );

      final ref = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/events/$eventId/cover.jpg',
      );
      uploadedPath = ref.fullPath;
      await ref.putFile(_image!, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('setSocialEventCover')
          .call({
            'eventId': eventId,
            'coverImageUrl': url,
            'coverStoragePath': ref.fullPath,
          });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (uploadedPath != null) {
        // Don't delete a successfully attached cover; cleanup only matters on failed attach.
      }
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Etkinlik Oluştur')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
        children: [
          GestureDetector(
            onTap: _saving ? null : _chooseImage,
            child: Container(
              height: 220,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.xLarge),
                border: Border.all(color: AppColors.border),
              ),
              child: _image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 48,
                          color: AppColors.violetBright,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Etkinlik kapak fotoğrafı ekle',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Kameradan çek veya galeriden seç',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_image!, fit: BoxFit.cover),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: FilledButton.tonalIcon(
                            onPressed: _saving ? null : _chooseImage,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Değiştir'),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Etkinlik başlığı',
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SocialEventType>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Etkinlik türü'),
            items: SocialEventType.values
                .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                .toList(),
            onChanged: _saving
                ? null
                : (value) =>
                      setState(() => _type = value ?? SocialEventType.social),
          ),
          if (_type == SocialEventType.other) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customType,
              decoration: const InputDecoration(
                labelText: 'Etkinlik türünün adı',
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<EventVisibility>(
            initialValue: _visibility,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kimler görebilir?',
              prefixIcon: Icon(Icons.shield_outlined),
            ),
            items: EventVisibility.values
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Row(
                      children: [
                        Icon(_visibilityIcon(e), size: 18),
                        const SizedBox(width: 8),
                        Text(e.label),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _visibility = value ?? EventVisibility.public;
                    if (_visibility != EventVisibility.selectedPeople) {
                      _selectedPeople = {};
                    }
                  }),
          ),
          if (_visibility == EventVisibility.selectedPeople) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      final value = await _pickPeople(
                        _selectedPeople.keys.toSet(),
                      );
                      if (mounted) setState(() => _selectedPeople = value);
                    },
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(
                _selectedPeople.isEmpty
                    ? 'Kişileri seç'
                    : '${_selectedPeople.length} kişi seçildi',
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.confirmation_number_outlined, color: AppColors.cyan),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ücretsiz etkinlik',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ücretli etkinlikler şimdilik kapalı.',
                        style: TextStyle(color: Colors.white54, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(
              labelText: 'Şehir',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'Etkinlik / buluşma adresi',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _chooseLocation,
              icon: Icon(
                _selectedLocation == null
                    ? Icons.map_outlined
                    : Icons.location_on_rounded,
              ),
              label: Text(
                _selectedLocation == null
                    ? 'Haritadan kesin konumu seç'
                    : 'Harita konumu seçildi • Değiştir',
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Tarih ve saat'),
            subtitle: Text(_dateLabel()),
            trailing: const Icon(Icons.chevron_right),
            onTap: _saving ? null : _chooseDateTime,
          ),
          TextField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Katılımcı kapasitesi',
              prefixIcon: Icon(Icons.groups_2_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Açıklama / not'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_available_outlined),
              label: Text(_saving ? 'Oluşturuluyor…' : 'Etkinliği Oluştur'),
            ),
          ),
        ],
      ),
    );
  }
}
