import 'package:flutter_test/flutter_test.dart';
import 'package:bilis_hatid_rider/core/utils/scan_code_parser.dart';

void main() {
  group('ScanCodeParser', () {
    test('valid numeric string returns integer', () {
      expect(ScanCodeParser.parse('1042'), 1042);
    });

    test('numeric string with surrounding whitespace returns integer', () {
      expect(ScanCodeParser.parse('  1042  '), 1042);
    });

    test('single zero is valid and returns 0', () {
      expect(ScanCodeParser.parse('0'), 0);
    });

    test('BH- prefixed code returns null', () {
      expect(ScanCodeParser.parse('BH-1042'), null);
    });

    test('numeric string with alpha suffix returns null', () {
      expect(ScanCodeParser.parse('1042abc'), null);
    });

    test('phone-like number with leading + returns null', () {
      expect(ScanCodeParser.parse('+63912345678'), null);
    });

    test('empty string returns null', () {
      expect(ScanCodeParser.parse(''), null);
    });

    test('whitespace-only string returns null', () {
      expect(ScanCodeParser.parse('   '), null);
    });
  });
}
