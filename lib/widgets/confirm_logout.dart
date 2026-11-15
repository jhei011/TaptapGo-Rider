import 'package:flutter/material.dart';
import '../core/services/rider_idle_policy.dart' show WorkCheck;
import '../core/theme/app_colors.dart';

/// The "Log out?" dialog, copied from TaptapShop's confirmLogout: a red logout icon in a soft
/// circle, the question, one line on what happens, and Cancel / Log out side by side.
/// Returns true when the user chose Log out.
Future<bool> confirmLogoutDialog(BuildContext context,
    {String message = "You'll need to sign in again to take jobs.",
    String title = 'Log out?',
    String confirmLabel = 'Log out'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => Dialog(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: C.dangerBg, shape: BoxShape.circle),
            child: Icon(Icons.logout_rounded, size: 28, color: C.danger),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(fontSize: 14, height: 1.4, color: C.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.textPrimary,
                  side: BorderSide(color: C.border),
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.dangerFill,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: Text(confirmLabel),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return ok == true;
}

/// Logging out with work in hand. Deliveries saved on this phone and not sent yet block the
/// logout (they would be stranded); jobs, offers or trips on the server (or no answer from
/// the server) get a clear warning, since logging out does not cancel or hand them back.
/// Returns true when the rider may be logged out.
Future<bool> confirmRiderLogout(BuildContext context, {
  required int unsentDeliveries,
  required Future<WorkCheck> Function() checkWork,
  required String message,
}) async {
  if (unsentDeliveries > 0) {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text('Deliveries not sent yet', style: TextStyle(color: C.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          '$unsentDeliveries ${unsentDeliveries == 1 ? 'delivery is' : 'deliveries are'} saved on this phone and '
          'not sent to the server yet. Connect to the internet so ${unsentDeliveries == 1 ? 'it is' : 'they are'} '
          'sent before you log out.',
          style: TextStyle(color: C.textSecondary, height: 1.4),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('OK'))],
      ),
    );
    return false;
  }
  final work = await checkWork();
  if (!context.mounted) return false;
  if (work == WorkCheck.none) return confirmLogoutDialog(context, message: message);
  return confirmLogoutDialog(
    context,
    title: 'You still have active work',
    message: work == WorkCheck.active
        ? 'You have a job, offer or trip that is not finished. Logging out does not cancel it or give it '
          'back: it stays assigned to you. Finish it first, or ask your hub to reassign it.'
        : 'The server could not be reached to check your jobs. If you have a delivery in progress, finish it '
          'first. Logging out does not cancel or give back your jobs.',
    confirmLabel: 'Log out anyway',
  );
}
