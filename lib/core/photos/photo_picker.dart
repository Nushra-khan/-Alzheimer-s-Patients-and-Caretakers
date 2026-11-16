import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Lets the user take or choose a photo, then crops it to a centred square
/// and shrinks it to 512 x 512 JPEG, small enough to upload on mobile data.
/// Returns null if the user cancels.
Future<Uint8List?> pickSquarePhoto({required bool fromCamera}) async {
  final picked = await ImagePicker().pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 92,
    preferredCameraDevice: CameraDevice.front,
  );
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  // Decoding and resizing is slow; keep it off the UI thread.
  return compute(_cropToSquareJpeg, bytes);
}

Uint8List _cropToSquareJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('This photo could not be read.');
  }
  // Respect the phone's rotation flag so portraits are not sideways.
  final upright = img.bakeOrientation(decoded);
  final square = img.copyResizeCropSquare(
    upright,
    size: 512,
    interpolation: img.Interpolation.average,
  );
  return Uint8List.fromList(img.encodeJpg(square, quality: 85));
}
