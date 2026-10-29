import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../widgets/birthday_dialog.dart';

class BirthdayService {
  static const String birthdayBoxName = 'birthday_wishes';

  static Future<void> checkAndShowBirthdayWish(BuildContext context, UserAccount user) async {
    if (user.dob == null) return;

    final now = DateTime.now();
    final dob = user.dob!;

    // Check if today is the birthday (ignoring year)
    if (dob.day == now.day && dob.month == now.month) {
      final box = await Hive.openBox(birthdayBoxName);
      final String wishKey = 'wished_${user.id}_${now.year}_${now.month}_${now.day}';
      
      final bool alreadyWished = box.get(wishKey, defaultValue: false);

      if (!alreadyWished) {
        // Show dialog
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => BirthdayDialog(user: user),
          );
          
          // Mark as wished for today
          await box.put(wishKey, true);
        }
      }
    }
  }
}
