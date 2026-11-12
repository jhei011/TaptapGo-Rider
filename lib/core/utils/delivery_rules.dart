/// The rules the rider app checks itself before sending a delivery or a license update,
/// so the rider gets the reason straight away (RID-DLV-005, RID-PROF-004).
class DeliveryRules {
  /// The amount collected must match the order to the centavo: ₱499.99 and ₱500.01 are
  /// both refused for a ₱500.00 COD order.
  static String? codProblem({required double expected, required String entered}) {
    final text = entered.trim();
    if (text.isEmpty) return 'Enter the COD amount you collected.';
    final value = double.tryParse(text.replaceAll(',', ''));
    if (value == null) return 'Enter a valid COD amount.';
    if ((value - expected).abs() >= 0.005) {
      return 'The COD amount must match the order exactly (₱${expected.toStringAsFixed(2)}).';
    }
    return null;
  }

  /// A license expiring today is still valid; yesterday or earlier is expired.
  static String? licenseExpiryProblem(DateTime? expiry, {DateTime? today}) {
    if (expiry == null) return 'Choose the license expiry date.';
    final now = today ?? DateTime.now();
    final day = DateTime(expiry.year, expiry.month, expiry.day);
    final startOfToday = DateTime(now.year, now.month, now.day);
    if (day.isBefore(startOfToday)) {
      return 'This license has expired. Choose today or a later date.';
    }
    return null;
  }
}
