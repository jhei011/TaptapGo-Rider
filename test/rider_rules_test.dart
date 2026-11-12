import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taptap_go/core/utils/attachment_rules.dart';
import 'package:taptap_go/core/utils/delivery_rules.dart';

/// The rules behind RID-PROF-004/005 and RID-DLV-005, checked without the server.
void main() {
  group('COD must match the order exactly (RID-DLV-005)', () {
    test('₱500.00 completes the delivery', () {
      expect(DeliveryRules.codProblem(expected: 500, entered: '500.00'), isNull);
      expect(DeliveryRules.codProblem(expected: 500, entered: '500'), isNull);
    });

    test('one centavo under or over is refused', () {
      expect(DeliveryRules.codProblem(expected: 500, entered: '499.99'),
          'The COD amount must match the order exactly (₱500.00).');
      expect(DeliveryRules.codProblem(expected: 500, entered: '500.01'),
          'The COD amount must match the order exactly (₱500.00).');
    });

    test('an empty or unreadable amount asks for it again', () {
      expect(DeliveryRules.codProblem(expected: 500, entered: ''), 'Enter the COD amount you collected.');
      expect(DeliveryRules.codProblem(expected: 500, entered: 'abc'), 'Enter a valid COD amount.');
    });
  });

  group('License expiry boundary (RID-PROF-004)', () {
    final today = DateTime(2026, 10, 21, 15, 30);

    test('yesterday is expired', () {
      expect(DeliveryRules.licenseExpiryProblem(DateTime(2026, 10, 20), today: today),
          'This license has expired. Choose today or a later date.');
    });

    test('today and later are accepted', () {
      expect(DeliveryRules.licenseExpiryProblem(DateTime(2026, 10, 21), today: today), isNull);
      expect(DeliveryRules.licenseExpiryProblem(DateTime(2026, 10, 22), today: today), isNull);
    });

    test('no date chosen asks for one', () {
      expect(DeliveryRules.licenseExpiryProblem(null, today: today), 'Choose the license expiry date.');
    });
  });

  group('Upload rules (RID-PROF-005, A16, M7)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('rider_upload_'));
    tearDown(() => dir.deleteSync(recursive: true));

    File file(String name, List<int> head, {int size = 16}) {
      final bytes = Uint8List(size);
      bytes.setRange(0, head.length.clamp(0, size), head);
      return File('${dir.path}${Platform.pathSeparator}$name')..writeAsBytesSync(bytes);
    }

    const jpeg = [0xFF, 0xD8, 0xFF, 0xE0];
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    const pdf = [0x25, 0x50, 0x44, 0x46];

    test('a real JPG, PNG or PDF is accepted', () async {
      expect(await AttachmentRules.validate(file('a.jpg', jpeg)), isNull);
      expect(await AttachmentRules.validate(file('b.png', png)), isNull);
      expect(await AttachmentRules.validate(file('c.pdf', pdf)), isNull);
    });

    test('exactly 5.0 MB is accepted, 5.1 MB is refused', () async {
      const accepted = 5120 * 1024;
      const refused = 5222 * 1024;
      expect(await AttachmentRules.validate(file('ok.jpg', jpeg, size: accepted)), isNull);
      expect(await AttachmentRules.validate(file('big.jpg', jpeg, size: refused)),
          'The file is too large. The maximum size is 5 MB.');
    });

    test('the type is read from the content, not the name', () async {
      // A Word document and a renamed executable both ending in .jpg
      expect(await AttachmentRules.validate(file('price_list.docx', [0x50, 0x4B, 0x03, 0x04])),
          'Only JPG, PNG or PDF files are accepted.');
      expect(await AttachmentRules.validate(file('renamed_exe.jpg', [0x4D, 0x5A])),
          'Only JPG, PNG or PDF files are accepted.');
    });

    test('proof-of-delivery photos must be JPG or PNG, never a PDF', () async {
      expect(await AttachmentRules.validate(file('pod.pdf', pdf), kind: AttachmentKind.image),
          'Only JPG or PNG photos are accepted.');
      expect(await AttachmentRules.validate(file('pod.jpg', jpeg), kind: AttachmentKind.image), isNull);
    });
  });
}
