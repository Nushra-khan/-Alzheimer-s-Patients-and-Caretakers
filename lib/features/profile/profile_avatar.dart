import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A round profile photo with the person's initial when there is no photo
/// (or it cannot load, e.g. offline).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.radius = 32,
  });

  final String name;
  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryContainer,
      foregroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
      onForegroundImageError: hasPhoto ? (_, _) {} : null,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}

/// Asks whether to take a photo or choose one. Returns true for the camera,
/// false for the gallery, or null when cancelled.
Future<bool?> askPhotoSource(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(sheetContext).pop(false),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
