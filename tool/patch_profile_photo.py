from pathlib import Path


def main() -> None:
    path = Path('lib/screens/profile_page.dart')
    text = path.read_text()

    if "package:firebase_storage/firebase_storage.dart" not in text:
        text = text.replace(
            "import 'package:firebase_auth/firebase_auth.dart';\n",
            "import 'package:firebase_auth/firebase_auth.dart';\n"
            "import 'package:firebase_storage/firebase_storage.dart';\n",
            1,
        )
    if "package:image_picker/image_picker.dart" not in text:
        text = text.replace(
            "import 'package:flutter/material.dart';\n",
            "import 'package:flutter/material.dart';\n"
            "import 'package:image_picker/image_picker.dart';\n",
            1,
        )

    state_marker = '''class _InstagramStyleProfileState
    extends State<_InstagramStyleProfile> {
'''
    if state_marker in text and '_avatarPicker' not in text:
        text = text.replace(
            state_marker,
            state_marker
            + "  final ImagePicker _avatarPicker = ImagePicker();\n"
            + "  bool _uploadingAvatar = false;\n\n",
            1,
        )

    init_end = '''  @override
  void initState() {
    super.initState();
    SocialService.instance.ensureUserProfile();
  }

'''
    if init_end in text and 'Future<void> _changeProfilePhoto()' not in text:
        method = r'''  Future<void> _changeProfilePhoto() async {
    if (_uploadingAvatar) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil fotoğrafı için önce giriş yapmalısın.')),
        );
      }
      return;
    }

    try {
      final picked = await _avatarPicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploadingAvatar = true);

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child(user.uid)
          .child('avatar.jpg');

      await ref.putFile(
        File(picked.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final photoUrl = await ref.getDownloadURL();

      await user.updatePhotoURL(photoUrl);
      await user.reload();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafın güncellendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil fotoğrafı yüklenemedi: $e')),
      );
    }
  }

'''
        text = text.replace(init_end, init_end + method, 1)

    text = text.replace(
        '    final user = widget.user;\n',
        '    final user = FirebaseAuth.instance.currentUser ?? widget.user;\n',
        1,
    )

    old_avatar = '''                                CircleAvatar(
                                  radius: 46,
                                  backgroundColor:
                                      const Color(0xFFFFC107),
                                  child: CircleAvatar(
                                    radius: 42,
                                    backgroundColor:
                                        const Color(0xFF171C24),
                                    backgroundImage:
                                        photoUrl.isNotEmpty
                                            ? NetworkImage(
                                                photoUrl,
                                              )
                                            : null,
                                    child: photoUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 48,
                                            color:
                                                Colors.white54,
                                          )
                                        : null,
                                  ),
                                ),
'''
    new_avatar = '''                                GestureDetector(
                                  onTap: _uploadingAvatar
                                      ? null
                                      : _changeProfilePhoto,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      CircleAvatar(
                                        radius: 46,
                                        backgroundColor:
                                            const Color(0xFFFFC107),
                                        child: CircleAvatar(
                                          radius: 42,
                                          backgroundColor:
                                              const Color(0xFF171C24),
                                          backgroundImage:
                                              photoUrl.isNotEmpty
                                                  ? NetworkImage(photoUrl)
                                                  : null,
                                          child: _uploadingAvatar
                                              ? const Padding(
                                                  padding: EdgeInsets.all(24),
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 3,
                                                    color: Color(0xFFFFC107),
                                                  ),
                                                )
                                              : photoUrl.isEmpty
                                                  ? const Icon(
                                                      Icons.person,
                                                      size: 48,
                                                      color: Colors.white54,
                                                    )
                                                  : null,
                                        ),
                                      ),
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFC107),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF0D1117),
                                            width: 3,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 15,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
'''
    if old_avatar in text:
        text = text.replace(old_avatar, new_avatar, 1)

    settings_anchor = '''                _SettingsTile(
                  icon: Icons.add_a_photo_outlined,
                  title: 'Fotoğraf Paylaş',
'''
    if settings_anchor in text and "title: 'Profil Fotoğrafını Değiştir'" not in text:
        profile_tile = '''                _SettingsTile(
                  icon: Icons.account_circle_outlined,
                  title: 'Profil Fotoğrafını Değiştir',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _changeProfilePhoto();
                  },
                ),
'''
        text = text.replace(settings_anchor, profile_tile + settings_anchor, 1)

    # profile_page now uses File for Firebase Storage upload.
    if "import 'dart:io';" not in text:
        text = "import 'dart:io';\n\n" + text

    path.write_text(text)
    print('Profile photo picker/upload patch applied')


if __name__ == '__main__':
    main()
