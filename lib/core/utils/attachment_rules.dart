import 'dart:io';

/// Whether an upload is a document (JPG, PNG or PDF) or a photo (JPG or PNG).
enum AttachmentKind { document, image }

/// Upload rules the rider app enforces before sending anything (A16, M7, RID-PROF-005,
/// RID-DLV-003): at most 5 MB, and the type is read from the file's first bytes, so a
/// renamed .exe or .docx is refused even when its name ends in .jpg.
class AttachmentRules {
  /// 5.0 MB, exactly 5,120 KB: a file of this size is accepted, anything larger is not.
  static const int maxBytes = 5 * 1024 * 1024;

  static const String _documentsMessage = 'Only JPG, PNG or PDF files are accepted.';
  static const String _photosMessage = 'Only JPG or PNG photos are accepted.';
  static const String sizeMessage = 'The file is too large. The maximum size is 5 MB.';

  /// Returns null when [file] may be uploaded, otherwise the message to show the rider.
  static Future<String?> validate(File file, {AttachmentKind kind = AttachmentKind.document}) async {
    final int length;
    try {
      length = await file.length();
    } catch (_) {
      return 'This file cannot be read. Choose it again.';
    }
    if (length > maxBytes) return sizeMessage;

    final type = await _sniff(file);
    if (type == null) {
      return kind == AttachmentKind.image ? _photosMessage : _documentsMessage;
    }
    if (kind == AttachmentKind.image && type == _FileType.pdf) return _photosMessage;
    return null;
  }

  /// Reads the file signature (magic bytes), never trusting the extension.
  static Future<_FileType?> _sniff(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final head = await raf.read(8);
      if (head.length >= 3 && head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF) {
        return _FileType.jpeg;
      }
      if (head.length >= 8 &&
          head[0] == 0x89 && head[1] == 0x50 && head[2] == 0x4E && head[3] == 0x47 &&
          head[4] == 0x0D && head[5] == 0x0A && head[6] == 0x1A && head[7] == 0x0A) {
        return _FileType.png;
      }
      if (head.length >= 4 && head[0] == 0x25 && head[1] == 0x50 && head[2] == 0x44 && head[3] == 0x46) {
        return _FileType.pdf;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      await raf?.close();
    }
  }
}

enum _FileType { jpeg, png, pdf }
