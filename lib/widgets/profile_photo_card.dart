import 'package:flutter/material.dart';
import 'firebase_media_image.dart';

Future<void> showProfilePhotoCard(BuildContext context, {
  required String userId, required String photoUrl, required String name,
  String username = '', VoidCallback? onViewStory,
}) => showDialog<void>(context: context, builder: (dialogContext) => Dialog(
  clipBehavior: Clip.antiAlias,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 420),
    child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Stack(children: [
        AspectRatio(aspectRatio: 1, child: FirebaseMediaImage(
          imageUrl: photoUrl,
          fallbackStoragePaths: FirebaseMediaImage.avatarPaths(userId),
          fit: BoxFit.contain,
          errorWidget: const Center(child: Icon(Icons.person_outline, size: 96)),
        )),
        Positioned(top: 8, right: 8, child: IconButton.filledTonal(
          tooltip: 'Kapat', onPressed: () => Navigator.pop(dialogContext),
          icon: const Icon(Icons.close),
        )),
      ]),
      Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Text(name, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge),
        if (username.trim().isNotEmpty) Text(
          '@${username.trim().replaceFirst(RegExp(r"^@"), "")}',
          textAlign: TextAlign.center),
        if (onViewStory != null) TextButton(
          onPressed: () { Navigator.pop(dialogContext); onViewStory(); },
          child: const Text('Hikâyeyi görüntüle'),
        ),
      ])),
    ])),
  ),
));
