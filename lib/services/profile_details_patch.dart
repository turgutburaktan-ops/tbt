/// A text-only edit must not replace a Firestore avatar with Auth's stale URL.
Map<String, dynamic> profileDetailsPatch({
  required String displayName,
  required String bio,
  String? uploadedPhotoUrl,
}) => {
  'displayName': displayName,
  'bio': bio,
  if (uploadedPhotoUrl != null && uploadedPhotoUrl.isNotEmpty)
    'photoUrl': uploadedPhotoUrl,
};
