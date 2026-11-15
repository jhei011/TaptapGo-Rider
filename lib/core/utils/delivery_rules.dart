/// The rules the rider app checks itself before sending a delivery or a license update,
/// so the rider gets the reason straight away (RID-DLV-005, RID-PROF-004).
class DeliveryRules {
  /// The cash collected must match the cash to collect to the centavo: ₱499.99 and ₱500.01
  /// are both refused when ₱500.00 is due. On an order paid partly with TapTapPay that is
  /// only the cash part, never the order total. Compared in whole centavos, as the server does.
  static String? codProblem({required double expected, required String entered}) {
    final text = entered.trim();
    if (text.isEmpty) return 'Enter the COD amount you collected.';
    final value = double.tryParse(text.replaceAll(',', ''));
    if (value == null) return 'Enter a valid COD amount.';
    if ((value * 100).round() != (expected * 100).round()) {
      return 'Collect exactly ₱${expected.toStringAsFixed(2)} in cash. The amount must match to the centavo.';
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
