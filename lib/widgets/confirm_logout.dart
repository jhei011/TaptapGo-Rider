import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// The "Log out?" dialog, copied from TaptapShop's confirmLogout: a red logout icon in a soft
/// circle, the question, one line on what happens, and Cancel / Log out side by side.
/// Returns true when the user chose Log out.
Future<bool> confirmLogoutDialog(BuildContext context,
    {String message = "You'll need to sign in again to take jobs."}) async {
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
          Text('Log out?',
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
                child: const Text('Log out'),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return ok == true;
}
