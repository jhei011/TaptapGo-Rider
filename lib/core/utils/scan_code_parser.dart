/// Parses a raw string scanned from a QR or barcode into an order ID integer.
///
/// Accepted formats:
///   - An all-digit string (e.g. "1042")  →  returns the integer value.
///   - Leading/trailing whitespace is trimmed before the check.
///
/// Rejected formats (returns null):
///   - Empty or whitespace-only string.
///   - Any string containing non-digit characters (e.g. "BH-1042", "+63912…").
///
/// NOTE: The "BH-" prefix pattern is reserved for future use once the backend
/// defines the canonical order-code format (OD-01). At that point this parser
/// will be extended to accept the prefixed form.
class ScanCodeParser {
  /// Returns the integer order ID, or [null] if [raw] is not a recognised code.
  static int? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return int.tryParse(trimmed);
    return null;
  }
}
