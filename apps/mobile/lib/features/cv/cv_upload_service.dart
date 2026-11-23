import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/supabase_config.dart';

class UploadedCv {
  const UploadedCv({required this.id, required this.name});
  final String id;
  final String name;
}

class CvUploadService {
  static const maxBytes = 10 * 1024 * 1024;
  static const _uuid = Uuid();

  static String _mimeFor(String name) {
    switch (name.split('.').last.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        throw const FormatException('Only PDF, DOCX, PNG and JPG files are supported');
    }
  }

  static bool _hasExpectedSignature(Uint8List bytes, String mime) {
    if (mime == 'application/pdf') {
      return bytes.length >= 5 && bytes[0] == 0x25 && bytes[1] == 0x50 &&
          bytes[2] == 0x44 && bytes[3] == 0x46 && bytes[4] == 0x2d;
    }
    if (mime == 'image/png') {
      const magic = [137, 80, 78, 71, 13, 10, 26, 10];
      return bytes.length >= 8 &&
          List.generate(8, (i) => bytes[i] == magic[i]).every((ok) => ok);
    }
    if (mime == 'image/jpeg') {
      return bytes.length >= 3 &&
          bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    }
    // DOCX uses ZIP magic. Backend must subsequently validate archive structure.
    return bytes.length >= 4 &&
        bytes[0] == 0x50 && bytes[1] == 0x4b &&
        bytes[2] == 0x03 && bytes[3] == 0x04;
  }

  /// Returns null if the user cancels the picker.
  static Future<UploadedCv?> pickAndUpload() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before uploading your CV');
    }
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'png', 'jpg', 'jpeg'],
      withData: true,
      allowMultiple: false,
    );
    if (selected == null || selected.files.isEmpty) return null;
    final picked = selected.files.single;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Choose a file between 1 byte and 10 MB');
    }
    final mime = _mimeFor(picked.name);
    if (!_hasExpectedSignature(bytes, mime)) {
      throw const FormatException('The selected file format is invalid');
    }

    final path = '${user.id}/${_uuid.v4()}.${picked.extension?.toLowerCase() ?? 'bin'}';
    final client = SupabaseConfig.client;
    await client.storage.from('cv-private').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );

    try {
      final metadata = await client.from('cvs').insert({
        'user_id': user.id,
        'storage_path': path,
        'original_name': picked.name,
        'mime_type': mime,
        'size_bytes': bytes.length,
      }).select('id').single();
      return UploadedCv(id: metadata['id'] as String, name: picked.name);
    } catch (_) {
      // Compensate for an orphaned private object if metadata insert fails.
      try {
        await client.storage.from('cv-private').remove([path]);
      } catch (_) {
        // Safe orphan cleanup also needs a periodic backend worker.
      }
      rethrow;
    }
  }
}
